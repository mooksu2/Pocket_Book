// Views/DisplayLinkProxy.swift
import UIKit

/// CADisplayLink/Timer의 target retain 사이클을 끊는 약한 프록시.
final class DisplayLinkProxy: NSObject {
    weak var target: AnyObject?
    private let sel: Selector
    init(target: AnyObject, selector: Selector) {
        self.target = target
        self.sel = selector
    }
    @objc func tick() {
        _ = target?.perform(sel)
    }
}
