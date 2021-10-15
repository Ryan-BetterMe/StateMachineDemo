//
//  OOPStateMachine.swift
//  StateMachine
//
//  Created by Ryan on 2021/7/1.
//
// 采用面向对象的方式来创建状态机的DEMO，所以状态是作为第一要素的。

import Foundation

protocol OOEvent: Hashable {}

/// 状态类
/// PS: 由每一个状态类来存储转换规则
class OOState<E: OOEvent> {
    // 转换：key为触发事件 value为结束状态
    open var transition: [E: OOState] = [:]
    
    open func addTransition(_ event: E, to finalState: OOState) {
        transition[event] = finalState
    }
    
    open func enter() {}
    
    open func exit() {}
}

/// 状态机类
/// PS：管理有限个状态之间的相互转换
class OOStateMachine<E: OOEvent> {
    typealias State = OOState<E>
    
    public var currentState: State!
    
    private let workQueue = DispatchQueue.init(label: "com.ryan.statemachine.workQueue")
    
    init(_ initialState: State) {
        self.currentState = initialState
    }
    
    public func trigger(_ event: E) {
        workQueue.async {
            guard let finalState = self.currentState.transition[event] else { return }
            
            self.currentState.exit()
            
            self.currentState = finalState
            
            self.currentState.enter()
        }
    }
}

/* 实际使用：直接继承该State类，满足该类的方法 */
enum GameEvent: OOEvent {
    case speed
    case walk
    case stop
}

class RunState: OOState<GameEvent> {
    override func enter() {
        super.enter()
        
        sleep(2)
        NSLog("我穿上了运动鞋，我开始跑步了")
    }
    
    override func exit() {
        super.exit()
        
        NSLog("不跑了")
    }
}

class WalkState: OOState<GameEvent> {
    override func enter() {
        super.enter()
        
        sleep(1)
        NSLog("我换上了休闲鞋，开始走路了")
    }
    
    override func exit() {
        super.exit()
        
        NSLog("不走了")
    }
}

class RestState: OOState<GameEvent> {
    override func enter() {
        super.enter()
        
        sleep(1)
        NSLog("我穿上了睡衣，准备休息了")
    }
    
    override func exit() {
        super.exit()
        
        NSLog("不休息了")
    }
}
