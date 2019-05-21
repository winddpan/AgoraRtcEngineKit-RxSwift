//
//  AgoraRtcEngineKit+Rx.swift
//  HJSwift
//
//  Created by PAN on 2019/3/12.
//  Copyright © 2019 YR. All rights reserved.
//

import AgoraRtcEngineKit
import Foundation
import RxCocoa
import RxSwift

enum AgoraRtcRxError: Error {
    case localInvokeError
    case agoraError(AgoraErrorCode)
}

extension AgoraErrorCode: LocalizedError {
    fileprivate var isCommonError: Bool {
        return (rawValue > 0 && rawValue < 5) || rawValue == 10 || rawValue == 7
    }
    
    public var errorDescription: String? {
        return "AgoraErrorCode \(self.rawValue)"
    }
}

extension Reactive where Base: AgoraRtcEngineKit {
    var delegate: AgoraRtcEngineDelegateProxy {
        return AgoraRtcEngineDelegateProxy.proxy(for: base)
    }

    func addPublishStreamUrl(_ url: String, transcodingEnabled: Bool) -> Observable<String> {
        let success = delegate.streamPublishedSubject.asObserver().take(1)
        let error = delegate.didOccurErrorSubject.asObserver()
            .filter { $0.isCommonError || $0 == .publishFailed || $0 == .alreadyInUse }
            .take(1)
            .flatMap { error -> Observable<String> in
                Observable.error(AgoraRtcRxError.agoraError(error))
            }

        return engineInvoke(onSuccess: success, onError: error) {
            self.base.addPublishStreamUrl(url, transcodingEnabled: transcodingEnabled)
        }
    }

    func removePublishStreamUrl(_ url: String) -> Observable<String> {
        let success = delegate.streamUnpublishedSubject.asObserver().take(1).timeout(10, scheduler: MainScheduler.instance)
        let error = delegate.didOccurErrorSubject.asObserver()
            .filter { $0.isCommonError }
            .take(1)
            .flatMap { error -> Observable<String> in
                Observable.error(AgoraRtcRxError.agoraError(error))
            }

        return engineInvoke(onSuccess: success, onError: error) {
            self.base.removePublishStreamUrl(url)
        }
    }

    func joinChannel(byToken token: String?, channelId: String, info: String?, uid: UInt) -> Observable<(channel: String, uid: UInt)> {
        let success = delegate.didJoinChannelSubject.asObserver().take(1)
        let error = delegate.didOccurErrorSubject.asObserver()
            .filter { $0.isCommonError || $0 == .invalidChannelId || $0 == .joinChannelRejected }
            .take(1)
            .flatMap { error -> Observable<(channel: String, uid: UInt)> in
                Observable.error(AgoraRtcRxError.agoraError(error))
            }

        return engineInvoke(onSuccess: success, onError: error) {
            self.base.joinChannel(byToken: token, channelId: channelId, info: info, uid: uid, joinSuccess: nil)
        }
    }

    func leaveChannel() -> Observable<AgoraChannelStats> {
        let success = delegate.didLeaveChannelSubject.asObserver().take(1)
        let error = delegate.didOccurErrorSubject.asObserver()
            .filter { $0.isCommonError || $0 == .leaveChannelRejected || $0 == .invalidChannelId }
            .take(1)
            .flatMap { error -> Observable<AgoraChannelStats> in
                Observable.error(AgoraRtcRxError.agoraError(error))
            }

        return engineInvoke(onSuccess: success, onError: error) {
            self.base.leaveChannel(nil)
        }
    }

    func setLiveTranscoding(transcoding: AgoraLiveTranscoding) -> Observable<Void> {
        let success = delegate.rtcEngineTranscodingUpdatedSubject.asObserver().take(1)
        let error = delegate.didOccurErrorSubject.asObserver()
            .filter { $0.isCommonError }
            .take(1)
            .flatMap { error -> Observable<Void> in
                Observable.error(AgoraRtcRxError.agoraError(error))
            }

        return engineInvoke(onSuccess: success, onError: error) {
            self.base.setLiveTranscoding(transcoding)
        }
    }

    func didJoinedOfUid() -> Observable<UInt> {
        return delegate.methodInvoked(#selector(AgoraRtcEngineDelegate.rtcEngine(_:didJoinedOfUid:elapsed:)))
            .map { a in
                try castOptionalOrThrow(UInt.self, a[1])
            }
    }
    
    func firstRemoteVideoFrameOfUid() -> Observable<(UInt, CGSize)> {
        return delegate.methodInvoked(#selector(AgoraRtcEngineDelegate.rtcEngine(_:firstRemoteVideoFrameOfUid:size:elapsed:)))
            .map { a in
                try castOptionalOrThrow((UInt, CGSize).self, (a[1], a[2]))
        }
    }
    
    func firstRemoteAudioFrameOfUid() -> Observable<UInt> {
        return delegate.methodInvoked(#selector(AgoraRtcEngineDelegate.rtcEngine(_:firstRemoteAudioFrameOfUid:elapsed:)))
            .map { a in
                try castOptionalOrThrow(UInt.self, a[1])
        }
    }

    func didOfflineOfUid() -> Observable<UInt> {
        return delegate.methodInvoked(#selector(AgoraRtcEngineDelegate.rtcEngine(_:didOfflineOfUid:reason:)))
            .map { a in
                try castOptionalOrThrow(UInt.self, a[1])
            }
    }

    func reportAudioVolumeIndicationOfSpeakers() -> Observable<[AgoraRtcAudioVolumeInfo]> {
        return delegate.methodInvoked(#selector(AgoraRtcEngineDelegate.rtcEngine(_:reportAudioVolumeIndicationOfSpeakers:totalVolume:)))
            .map { a in
                try castOptionalOrThrow([AgoraRtcAudioVolumeInfo].self, a[1])
            }
    }
}

private func engineInvoke<T>(onSuccess: Observable<T>, onError: Observable<T>, method: @escaping (() -> Int32)) -> Observable<T> {
    return Observable<T>.create { (observer) -> Disposable in
        guard method() == 0 else {
            observer.onError(AgoraRtcRxError.localInvokeError)
            return Disposables.create()
        }

        let disposable = onSuccess.amb(onError).subscribe(observer)

        return Disposables.create {
            disposable.dispose()
        }
    }
}

private func castOptionalOrThrow<T>(_ resultType: T.Type, _ object: Any) throws -> T {
    guard let returnValue = object as? T else {
        throw RxCocoaError.castingError(object: object, targetType: resultType)
    }
    return returnValue
}
