//
//  SpeedTester.swift
//  LocalNetSpeed-tvos
//
//  Created by 林恩佑 on 2025/8/14.
//


import Foundation
import Network

final class SpeedTester {
    static let defaultPort: UInt16 = 65432
    static let defaultChunkSize = 1 * 1024 * 1024
    
    private var listener: NWListener?
    private var serverConnection: NWConnection?
    private var clientConnection: NWConnection?
    private var isCancelled = false
    
    func cancel() {
        isCancelled = true
        
        // 強制關閉所有連線
        serverConnection?.forceCancel()
        clientConnection?.forceCancel()
        
        // 停止監聽器
        listener?.cancel()
        
        // 清理引用
        serverConnection = nil
        clientConnection = nil
        listener = nil
    }
    
    private func cleanup() {
        serverConnection?.forceCancel()
        clientConnection?.forceCancel()
        listener?.cancel()
        
        serverConnection = nil
        clientConnection = nil
        listener = nil
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
        
        let startRef = Atomic<Date?>(nil)
        let totalBytes = Atomic<Int>(0)
        let connectionCount = Atomic<Int>(0)
        
        listener?.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            self.serverConnection = conn
            
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
                    self.cleanup()
                    completion(.failure(err))
                case .cancelled:
                    self.cleanup()
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
                self.cleanup()
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
                   completion: @escaping (Result<SpeedTestResult, Error>) -> Void) {
        isCancelled = false
        
        let conn = NWConnection(host: .init(host), port: .init(rawValue: port)!, using: .tcp)
        clientConnection = conn
        
        let startRef = Atomic<Date?>(nil)
        let sentBytes = Atomic<Int>(0)
        let targetBytes = totalSizeMB * 1024 * 1024
        
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                startRef.set(Date())
                self.sendLoop(connection: conn,
                               chunkSize: Self.defaultChunkSize,
                               targetBytes: targetBytes,
                               sentBytes: sentBytes,
                               progress: progress,
                               startRef: startRef,
                               completion: completion)
            case .failed(let err):
                self.cleanup()
                completion(.failure(err))
            case .cancelled:
                self.cleanup()
                if self.isCancelled {
                    completion(.failure(NSError(domain: "Cancelled", code: -999)))
                }
            default: break
            }
        }
        
        conn.start(queue: .global(qos: .userInitiated))
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
                self.cleanup()
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