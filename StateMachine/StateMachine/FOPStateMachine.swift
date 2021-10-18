//
//  FOPStateMachine.swift
//  StateMachine
//
//  Created by Ryan on 2021/10/15.
//
//  采用面向函数的状态机，那么核心应该是函数

import Foundation

public enum TransionResult {
    case success
    case failure
}

public typealias ExecutionBlock = (() -> Void)

public struct Transition<State, Event> {
    public let event: Event
    public let source: State
    public let destination: State
    
    let preAction: ExecutionBlock?
    let postAction: ExecutionBlock?
    
    init(with event: Event,
         from: State,
         to: State,
         preBlock: ExecutionBlock? = nil,
         postBlock: ExecutionBlock? = nil) {
        self.event = event
        self.source = from
        self.destination = to
        self.preAction = preBlock
        self.postAction = postBlock
    }
    
    public func executePreAction() {
        self.preAction?()
    }
    
    public func executePostAction() {
        self.postAction?()
    }
}

class StateMachine<State: Hashable, Event: Hashable> {
    public var currentState: State {
        return {
            workingQueue.sync {
                return internelState
            }
        }()
    }
    
    private var internelState: State
    
    /// 保证 Transition 的读写都线程安全
    private let lockQueue: DispatchQueue
    
    /// 保证 State 的读写都线程安全
    private let workingQueue: DispatchQueue
    
    /// 状态转换时，执行具体操作的线程(默认为主线程)
    private let executeQueue: DispatchQueue
    
    private var transitionsByEvent: [Event: [Transition<State, Event>]] = [:]
    
    /// 初始化状态机
    /// - Parameters:
    ///   - initialState: 初始状态
    ///   - executeQueue: 状态转换时，指定执行具体操作的队列
    init(_ initialState: State, _ executeQueue: DispatchQueue = .main) {
        self.internelState = initialState
        
        self.lockQueue = DispatchQueue.init(label: "com.ryan.statemachine.lockqueue")
        self.workingQueue = DispatchQueue.init(label: "com.ryan.statemachine.workqueue")
        self.executeQueue = executeQueue
    }
    
    public func add(_ transition: Transition<State, Event>) {
        lockQueue.sync {
            let event = transition.event
            
            if let tempTransitions = transitionsByEvent[event] {
                let sameElements = tempTransitions.filter { $0.source == transition.source }
                
                if sameElements.count > 0 {
                    assertionFailure("同一个transition被多次添加")
                } else {
                    transitionsByEvent[event]?.append(transition)
                }
            } else {
                transitionsByEvent[event] = [transition]
            }
        }
    }
    
    /// 状态机被触发
    /// - Parameters:
    ///   - event: 触发事件
    ///   - execution: 触发时要执行的Block（默认为nil）
    ///   - completion: 触发事件的回调(默认为nil)
    public func trigger(by event: Event, execution: (() -> Void)? = nil, completion: ((TransionResult) -> Void)? = nil) {
        var transitions: [Transition<State, Event>]?
        
        lockQueue.sync {
            transitions = transitionsByEvent[event]
        }
        
        workingQueue.async {
            let performTransitions = transitions?.filter { $0.source == self.internelState } ?? []
            
            if performTransitions.count != 1 {
                self.executeQueue.async {
                    completion?(.failure)
                }
                return
            }
            
            let performTransition = performTransitions.first!
            
            self.executeQueue.async {
                performTransition.executePreAction()
            }
            
            self.executeQueue.async {
                execution?()
            }
            
            self.internelState = performTransition.destination
            
            self.executeQueue.async {
                performTransition.executePostAction()
            }
            
            self.executeQueue.async {
                completion?(.success)
            }
        }
    }
}


