//
//  AgoraRtcEngineDelegateProxy.swift
//  HJSwift
//
//  Created by PAN on 2019/4/30.
//  Copyright © 2019 YR. All rights reserved.
//

import AgoraRtcEngineKit
import Foundation
import RxCocoa
import RxSwift

extension AgoraRtcEngineKit: HasDelegate {
    public typealias Delegate = AgoraRtcEngineDelegate
}

class AgoraRtcEngineDelegateProxy: DelegateProxy<AgoraRtcEngineKit, AgoraRtcEngineDelegate>, DelegateProxyType {
    private(set) weak var engineKit: AgoraRtcEngineKit?

    let didJoinChannelSubject = PublishSubject<(channel: String, uid: UInt)>()
    let didLeaveChannelSubject = PublishSubject<AgoraChannelStats>()
    let streamUnpublishedSubject = PublishSubject<String>()
    let streamPublishedSubject = PublishSubject<String>()
    let rtcEngineTranscodingUpdatedSubject = PublishSubject<Void>()
    let didOccurErrorSubject = PublishSubject<AgoraErrorCode>()

    deinit {
        didJoinChannelSubject.onCompleted()
        didLeaveChannelSubject.onCompleted()
        streamUnpublishedSubject.onCompleted()
        streamPublishedSubject.onCompleted()
        rtcEngineTranscodingUpdatedSubject.onCompleted()
        didOccurErrorSubject.onCompleted()
    }

    init(engineKit: ParentObject) {
        self.engineKit = engineKit
        super.init(parentObject: engineKit, delegateProxy: AgoraRtcEngineDelegateProxy.self)
    }

    static func registerKnownImplementations() {
        register { AgoraRtcEngineDelegateProxy(engineKit: $0) }
    }
}

extension AgoraRtcEngineDelegateProxy: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        didJoinChannelSubject.onNext((channel: channel, uid: uid))
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        didLeaveChannelSubject.onNext(stats)
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, streamUnpublishedWithUrl url: String) {
        streamUnpublishedSubject.onNext(url)
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, streamPublishedWithUrl url: String, errorCode: AgoraErrorCode) {
        streamPublishedSubject.onNext(url)
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        if errorCode.rawValue != 0 {
            didOccurErrorSubject.onNext(errorCode)
        }
    }

    func rtcEngineTranscodingUpdated(_ engine: AgoraRtcEngineKit) {
        rtcEngineTranscodingUpdatedSubject.onNext(())
    }
}
