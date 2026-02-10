//
//  SpeedTester.swift
//  LocalNetSpeed
//
//  Created by 林恩佑 on 2025/8/14.
//


import Foundation
import Network

final class SpeedTester {
    static let defaultPort: UInt16 = 65432
    static let defaultChunkSize = 1 * 1024 * 1024
    
    // 重試配置
    static let maxRetryAttempts = 50  // 增加重試次數
    static let retryDelaySeconds: TimeInterval = 2.0
    static let retryDelayIncrement: TimeInterval = 0.5  // 減少延遲增量
    
    private var listener: NWListener?
    private var serverConnection: NWConnection?
    private var clientConnection: NWConnection?
    private var isCancelled = false
    
    // 重試相關屬性
    private var currentRetryAttempt = 0
    private var retryTimer: Timer?
    private var connectionTimeoutTimer: Timer?
    
    func cancel() {
        isCancelled = true
        
        // 停止重試計時器
        retryTimer?.invalidate()
        retryTimer = nil
        
        // 停止連接超時計時器
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        // 強制關閉所有連線
        serverConnection?.forceCancel()
        clientConnection?.forceCancel()
        
        // 停止監聽器
        listener?.cancel()
        
        // 清理引用
        serverConnection = nil
        clientConnection = nil
        listener = nil
        
        // 重置重試狀態
        currentRetryAttempt = 0
    }
    
    private func cleanup() {
        retryTimer?.invalidate()
        retryTimer = nil
        
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        serverConnection?.forceCancel()
        clientConnection?.forceCancel()
        listener?.cancel()
        
        serverConnection = nil
        clientConnection = nil
        listener = nil
        
        currentRetryAttempt = 0
    }
    
    private func cleanupClientOnly() {
        retryTimer?.invalidate()
        retryTimer = nil
        
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        clientConnection?.forceCancel()
        clientConnection = nil
        
        currentRetryAttempt = 0
    }
}

// MARK: - Server
extension SpeedTester {
    func runServer(port: UInt16,
                   progress: @escaping (Int) -> Void,
                   completion: @escaping (Result<SpeedTestResult, Error>) -> Void,
                   onNewConnection: ((Int) -> Void)? = nil) {
        isCancelled = false
        
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            completion(.failure(error))
            return
        }
        
        let connectionCount = Atomic<Int>(0)
        
        listener?.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            self.serverConnection = conn
            
            // 每個連線獨立計算
            let startRef = Atomic<Date?>(nil)
            let totalBytes = Atomic<Int>(0)
            
            // 增加連線計數
            let currentCount = connectionCount.addAndGet(1)
            onNewConnection?(currentCount)
            
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    startRef.set(Date())
                    self.receiveLoop(connection: conn,
                                     totalBytes: totalBytes,
                                     progress: progress,
                                     startRef: startRef,
                                     completion: completion)
                case .failed(let err):
                    // 只關閉當前連接，不關閉整個伺服器
                    conn.cancel()
                    self.serverConnection = nil
                    completion(.failure(err))
                case .cancelled:
                    // 只關閉當前連接，不關閉整個伺服器
                    self.serverConnection = nil
                    if self.isCancelled {
                        completion(.failure(NSError(domain: "Cancelled", code: -999)))
                    }
                default: break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            if case .failed(let err) = state {
                self?.cleanup()
                completion(.failure(err))
            }
        }
        
        listener?.start(queue: .global(qos: .userInitiated))
    }
    
    private func receiveLoop(connection: NWConnection,
                             totalBytes: Atomic<Int>,
                             progress: @escaping (Int) -> Void,
                             startRef: Atomic<Date?>,
                             completion: @escaping (Result<SpeedTestResult, Error>) -> Void) {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: Self.defaultChunkSize) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                completion(.failure(error))
                return
            }
            if let data {
                let newTotal = totalBytes.addAndGet(data.count)
                progress(newTotal)
            }
            if isComplete {
                guard let start = startRef.get() else {
                    completion(.failure(NSError(domain: "NoStartTime", code: -2)))
                    return
                }
                let end = Date()
                let bytes = totalBytes.get()
                let duration = end.timeIntervalSince(start)
                let speed = (Double(bytes)/1024/1024)/max(duration, 0.0001)
                let eval = GigabitEvaluator.evaluate(speedMBps: speed)
                let result = SpeedTestResult(
                    transferredBytes: bytes,
                    duration: duration,
                    startedAt: start,
                    endedAt: end,
                    evaluation: eval
                )
                // 只關閉當前連接，不關閉整個伺服器
                connection.cancel()
                self.serverConnection = nil
                completion(.success(result))
                return
            }
            self.receiveLoop(connection: connection,
                             totalBytes: totalBytes,
                             progress: progress,
                             startRef: startRef,
                             completion: completion)
        }
    }
}

// MARK: - Client
extension SpeedTester {
    func runClient(host: String,
                   port: UInt16,
                   totalSizeMB: Int,
                   progress: @escaping (Int) -> Void,
                   completion: @escaping (Result<SpeedTestResult, Error>) -> Void,
                   retryStatus: @escaping (Int, Int) -> Void = { _, _ in },
                   enableRetry: Bool = true) {
        isCancelled = false
        currentRetryAttempt = 0
        
        attemptConnection(host: host,
                         port: port,
                         totalSizeMB: totalSizeMB,
                         progress: progress,
                         completion: completion,
                         retryStatus: retryStatus,
                         enableRetry: enableRetry)
    }
    
    private func attemptConnection(host: String,
                                  port: UInt16,
                                  totalSizeMB: Int,
                                  progress: @escaping (Int) -> Void,
                                  completion: @escaping (Result<SpeedTestResult, Error>) -> Void,
                                  retryStatus: @escaping (Int, Int) -> Void,
                                  enableRetry: Bool) {
        if isCancelled {
            completion(.failure(NSError(domain: "Cancelled", code: -999)))
            return
        }
        
        currentRetryAttempt += 1
        retryStatus(currentRetryAttempt, Self.maxRetryAttempts)
        
        let conn = NWConnection(host: .init(host), port: .init(rawValue: port)!, using: .tcp)
        clientConnection = conn
        
        let startRef = Atomic<Date?>(nil)
        let sentBytes = Atomic<Int>(0)
        let targetBytes = totalSizeMB * 1024 * 1024
        
        // 設置連接超時（30秒）
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.clientConnection === conn && conn.state != .ready {
                // 連接超時，強制失敗
                let timeoutError = NSError(domain: "ConnectionTimeout", code: -1004, 
                                         userInfo: [NSLocalizedDescriptionKey: "連接超時"])
                self.handleConnectionFailure(host: host, port: port, totalSizeMB: totalSizeMB, 
                                           progress: progress, completion: completion, 
                                           retryStatus: retryStatus, enableRetry: enableRetry, error: timeoutError)
            }
        }
        
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                // 連接成功，清除超時計時器
                self.connectionTimeoutTimer?.invalidate()
                self.connectionTimeoutTimer = nil
                
                startRef.set(Date())
                self.sendLoop(connection: conn,
                               chunkSize: Self.defaultChunkSize,
                               targetBytes: targetBytes,
                               sentBytes: sentBytes,
                               progress: progress,
                               startRef: startRef,
                               completion: completion)
            case .failed(let err):
                self.handleConnectionFailure(host: host,
                                            port: port,
                                            totalSizeMB: totalSizeMB,
                                            progress: progress,
                                            completion: completion,
                                            retryStatus: retryStatus,
                                            enableRetry: enableRetry,
                                            error: err)
            case .cancelled:
                self.cleanupClientOnly()
                if self.isCancelled {
                    completion(.failure(NSError(domain: "Cancelled", code: -999)))
                }
            default: break
            }
        }
        
        conn.start(queue: .global(qos: .userInitiated))
    }
    
    private func handleConnectionFailure(host: String,
                                       port: UInt16,
                                       totalSizeMB: Int,
                                       progress: @escaping (Int) -> Void,
                                       completion: @escaping (Result<SpeedTestResult, Error>) -> Void,
                                       retryStatus: @escaping (Int, Int) -> Void,
                                       enableRetry: Bool,
                                       error: Error) {
        // 清理當前連接
        clientConnection?.forceCancel()
        clientConnection = nil
        
        // 檢查是否應該重試
        if enableRetry && currentRetryAttempt < Self.maxRetryAttempts && !isCancelled {
            // 計算延遲時間（遞增延遲，但有上限）
            let baseDelay = Self.retryDelaySeconds + (Double(currentRetryAttempt - 1) * Self.retryDelayIncrement)
            let delay = min(baseDelay, 10.0)  // 最大延遲不超過10秒
            
            // 清理之前的計時器
            retryTimer?.invalidate()
            
            // 使用 DispatchQueue 而不是 Timer 來確保更可靠的調度
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, !self.isCancelled else { return }
                self.attemptConnection(host: host,
                                      port: port,
                                      totalSizeMB: totalSizeMB,
                                      progress: progress,
                                      completion: completion,
                                      retryStatus: retryStatus,
                                      enableRetry: enableRetry)
            }
        } else {
            // 達到最大重試次數或已取消，返回錯誤
            self.cleanupClientOnly()
            let finalError: Error
            if !enableRetry {
                finalError = NSError(domain: "ConnectionFailed", 
                                   code: -1002, 
                                   userInfo: [NSLocalizedDescriptionKey: "連線失敗：無法連接到伺服器。錯誤：\(error.localizedDescription)"])
            } else if currentRetryAttempt >= Self.maxRetryAttempts {
                finalError = NSError(domain: "ConnectionFailed", 
                                   code: -1001, 
                                   userInfo: [NSLocalizedDescriptionKey: "連線失敗：已達到最大重試次數 (\(Self.maxRetryAttempts) 次)。最後錯誤：\(error.localizedDescription)"])
            } else {
                finalError = error
            }
            completion(.failure(finalError))
        }
    }
    
    private func sendLoop(connection: NWConnection,
                          chunkSize: Int,
                          targetBytes: Int,
                          sentBytes: Atomic<Int>,
                          progress: @escaping (Int) -> Void,
                          startRef: Atomic<Date?>,
                          completion: @escaping (Result<SpeedTestResult, Error>) -> Void) {
        if isCancelled { return }
        let current = sentBytes.get()
        
        if current >= targetBytes {
            connection.send(content: nil,
                            contentContext: .finalMessage,
                            isComplete: true,
                            completion: .contentProcessed { _ in
                guard let start = startRef.get() else {
                    completion(.failure(NSError(domain: "NoStartTime", code: -2)))
                    return
                }
                let end = Date()
                let duration = end.timeIntervalSince(start)
                let speed = (Double(current)/1024/1024)/max(duration, 0.0001)
                let eval = GigabitEvaluator.evaluate(speedMBps: speed)
                let result = SpeedTestResult(
                    transferredBytes: current,
                    duration: duration,
                    startedAt: start,
                    endedAt: end,
                    evaluation: eval
                )
                self.cleanupClientOnly()
                completion(.success(result))
            })
            return
        }
        
        let remain = targetBytes - current
        let thisSize = min(remain, chunkSize)
        let data = Data(repeating: 0x58, count: thisSize)
        
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                completion(.failure(error))
                return
            }
            let newTotal = sentBytes.addAndGet(thisSize)
            progress(newTotal)
            self.sendLoop(connection: connection,
                          chunkSize: chunkSize,
                          targetBytes: targetBytes,
                          sentBytes: sentBytes,
                          progress: progress,
                          startRef: startRef,
                          completion: completion)
        })
    }
}

// MARK: - Atomic
final class Atomic<T> {
    private let lock = NSLock()
    private var value: T
    init(_ v: T) { value = v }
    func get() -> T { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ v: T) { lock.lock(); value = v; lock.unlock() }
    @discardableResult
    func addAndGet(_ delta: Int) -> Int where T == Int {
        lock.lock(); defer { lock.unlock() }
        value += delta
        return value
    }
}