//
//  Util.swift
//  Bottle
//
//  Created by Cobalt on 9/24/23.
//

import Nuke
import SwiftUI

extension String {
    var imageRequest: ImageRequest? {
        guard let url = URL(string: self) else { return nil }
        if contains("pximg.net") {
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue("https://www.pixiv.net", forHTTPHeaderField: "Referer")
            return ImageRequest(urlRequest: urlRequest)
        } else {
            return ImageRequest(url: url)
        }
    }

    var filename: String? {
        guard let url = URL(string: self) else { return nil }
        return url.lastPathComponent
    }
    
    var percentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}

extension Binding {
    static func initial(_ value: Value) -> Binding<Value> {
        return Binding(get: { value }, set: { _ in })
    }
    
    /// For Int-valued SwiftUI Slider
    /// https://stackoverflow.com/questions/65736518/how-do-i-create-a-slider-in-swiftui-for-an-int-type-property
    static func convert<TInt, TFloat>(from intBinding: Binding<TInt>) -> Binding<TFloat>
        where TInt: BinaryInteger, TFloat: BinaryFloatingPoint {
        Binding<TFloat> (
            get: { TFloat(intBinding.wrappedValue) },
            set: { intBinding.wrappedValue = TInt($0) }
        )
    }
}

extension View {
    @ViewBuilder func fit(width: Int?, height: Int?) -> some View {
        if let width = width, let height = height {
            aspectRatio(CGSize(width: width, height: height), contentMode: .fit)
        } else {
            self
        }
    }
    
    /// https://stackoverflow.com/questions/65191093/is-it-possible-to-flip-a-swiftui-view-vertically
    func flipped(_ axis: Axis = .horizontal, anchor: UnitPoint = .center) -> some View {
        switch axis {
        case .horizontal:
            return scaleEffect(CGSize(width: -1, height: 1), anchor: anchor)
        case .vertical:
            return scaleEffect(CGSize(width: 1, height: -1), anchor: anchor)
        }
    }
}

extension Dictionary {
    func at(_ key: Key?) -> Value? {
        guard let key = key else { return nil }
        return self[key]
    }
}

extension Dictionary where Value: Identifiable {
    /// Merge identifiable items into the dictionary.
    mutating func merge(_ items: [Value]?) where Key == Value.ID {
        guard let items = items else { return }
        merge(items.map { ($0.id, $0) }) { $1 }
    }
}

extension Dictionary where Value: Collection {
    /// Merge sequence items into the dictionary.
    mutating func merge<T>(_ items: [(Key?, T)]?) where Value == [T] {
        guard let items = items else { return }
        for (key, value) in items {
            guard let key = key else { continue }
            if self[key] == nil {
                self[key] = [value]
            } else {
                self[key]?.append(value)
            }
        }
    }
}
