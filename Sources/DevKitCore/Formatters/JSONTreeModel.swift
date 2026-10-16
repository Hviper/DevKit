import Foundation

public enum JSONValueType: String, Sendable {
    case object = "Object"
    case array = "Array"
    case string = "String"
    case number = "Number"
    case boolean = "Boolean"
    case null = "Null"
}

public final class JSONTreeNode: Identifiable, ObservableObject, @unchecked Sendable {
    public let id = UUID()
    public let key: String?
    public let value: Any?
    public let type: JSONValueType
    public let children: [JSONTreeNode]?
    @Published public var isExpanded: Bool

    public init(
        key: String?,
        value: Any?,
        type: JSONValueType,
        children: [JSONTreeNode]?,
        isExpanded: Bool = true
    ) {
        self.key = key
        self.value = value
        self.type = type
        self.children = children
        self.isExpanded = isExpanded
    }

    public var summary: String {
        switch type {
        case .object:
            let count = children?.count ?? 0
            return "{\(count) 个键值对}"
        case .array:
            let count = children?.count ?? 0
            return "[\(count) 个元素]"
        case .string:
            return "\"\(value as? String ?? "")\""
        case .number:
            if let num = value as? NSNumber {
                return "\(num)"
            }
            return "\(value ?? "")"
        case .boolean:
            if let b = value as? Bool {
                return b ? "true" : "false"
            }
            return "\(value ?? "")"
        case .null:
            return "null"
        }
    }

    public static func parse(from jsonString: String) -> JSONTreeNode? {
        guard let data = jsonString.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            return nil
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        return fromObject(key: nil, object: obj)
    }

    private static func fromObject(key: String?, object: Any) -> JSONTreeNode {
        if let dict = object as? [String: Any] {
            let sortedKeys = dict.keys.sorted()
            let children = sortedKeys.map { k in
                fromObject(key: k, object: dict[k]!)
            }
            return JSONTreeNode(key: key, value: nil, type: .object, children: children, isExpanded: true)
        } else if let arr = object as? [Any] {
            let children = arr.enumerated().map { idx, item in
                fromObject(key: "[\(idx)]", object: item)
            }
            return JSONTreeNode(key: key, value: nil, type: .array, children: children, isExpanded: true)
        } else if let str = object as? String {
            return JSONTreeNode(key: key, value: str, type: .string, children: nil)
        } else if let num = object as? NSNumber {
            // Check if boolean (CFBoolean)
            if CFGetTypeID(num as CFTypeRef) == CFBooleanGetTypeID() {
                return JSONTreeNode(key: key, value: num.boolValue, type: .boolean, children: nil)
            }
            return JSONTreeNode(key: key, value: num, type: .number, children: nil)
        } else if object is NSNull {
            return JSONTreeNode(key: key, value: nil, type: .null, children: nil)
        } else {
            return JSONTreeNode(key: key, value: "\(object)", type: .string, children: nil)
        }
    }

    public func setExpandedRecursively(_ expanded: Bool) {
        self.isExpanded = expanded
        children?.forEach { $0.setExpandedRecursively(expanded) }
    }
}
