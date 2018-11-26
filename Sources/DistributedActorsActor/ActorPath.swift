//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Represents the name and placement within the actor hierarchy of a given actor.
///
/// Names of user actors MUST:
/// - not start with `$` (those names are reserved for Swift Distributed Actors internal system actors)
/// - contain only ASCII characters and select special characters (listed in [[ValidPathSymbols.extraSymbols]]
///
/// - Example: `/user/master/worker`
public struct ActorPath: Equatable, Hashable {

    // TODO: we could reconsider naming here; historical naming is that "address is the entire thing" by Hewitt,
    //      Akka wanted to get closer to that but we had historical naming to take into account so we didn't
    // private var address: Address = "swift-distributed-actors://10.0.0.1:2552
    private var segments: [ActorPathSegment]

    public init(_ segments: [ActorPathSegment]) throws {
        guard !segments.isEmpty else {
            throw ActorPathError.illegalEmptyActorPath
        }
        self.segments = segments
    }

    public init(root: String) throws {
        try self.init([ActorPathSegment(root)])
    }

    public init(root: ActorPathSegment) throws {
        try self.init([root])
    }

    /// Appends a segment to this actor path
    mutating func append(segment: ActorPathSegment) {
        self.segments.append(segment)
    }

    /// Returns the name of the actor represented by this path.
    /// This is equal to the last path segments string representation.
    var name: String {
        return nameSegment.value
    }

    var nameSegment: ActorPathSegment {
        return segments.last! // it is guaranteed by construction that we have at least one segment
    }
}

extension ActorPath {
    public static func /(base: ActorPath, child: ActorPathSegment) -> ActorPath {
        var res = base
        res.append(segment: child)
        return res
    }
}

// TODO
extension ActorPath: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        let pathSegments: String = self.segments.map({ $0.value }).joined(separator: "/")
        return "/\(pathSegments)"
    }
    public var debugDescription: String {
        return "ActorPath(\(description))"
    }
}

/// Represents a single segment (actor name) of an ActorPath.
public struct ActorPathSegment: Equatable, Hashable {
    let value: String

    public init(_ name: String) throws {
        // TODO: may want to separate validation out, in case we create it from "known safe" strings
        try ActorPathSegment.validatePathSegment(name)
        self.value = name
    }

    static func validatePathSegment(_ name: String) throws {
        if name.isEmpty {
            throw ActorPathError.illegalActorPathElement(name: name, illegal: "", index: 0)
        }

        // TODO: benchmark
        func isValidASCII(_ scalar: Unicode.Scalar) -> Bool {
            return (scalar >= ValidActorPathSymbols.a && scalar <= ValidActorPathSymbols.z) ||
                (scalar >= ValidActorPathSymbols.A && scalar <= ValidActorPathSymbols.Z) ||
                (scalar >= ValidActorPathSymbols.zero && scalar <= ValidActorPathSymbols.nine) ||
                (ValidActorPathSymbols.extraSymbols.contains(scalar))
        }

        // TODO: accept hex and url encoded things as well
        // http://www.ietf.org/rfc/rfc2396.txt
        var pos = 0
        for c in name {
            let f = c.unicodeScalars.first

            if (f?.isASCII ?? false) && isValidASCII(f!) {
                pos += 1
                continue
            } else {
                throw ActorPathError.illegalActorPathElement(name: name, illegal: "\(c)", index: pos)
            }
        }
    }
}

extension ActorPathSegment: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "\(self.value)"
    }
    public var debugDescription: String {
        return "ActorPathSegment(\(self))"
    }
}

private struct ValidActorPathSymbols {
    // TODO: I suspect having those as numeric constants may be better for perf?
    static let a: UnicodeScalar = "a"
    static let z: UnicodeScalar = "z"
    static let A: UnicodeScalar = "A"
    static let Z: UnicodeScalar = "Z"
    static let zero: UnicodeScalar = "0"
    static let nine: UnicodeScalar = "9"

    static let extraSymbols: String.UnicodeScalarView = "-_.*$+:@&=,!~';".unicodeScalars
}

// MARK: --

public enum ActorPathError: Error {
    case illegalEmptyActorPath
    case illegalLeadingSpecialCharacter(name: String, illegal: Character)
    case illegalActorPathElement(name: String, illegal: String, index: Int)
    case rootPathSegmentRequiredToStartWithSlash(segment: ActorPathSegment)
}
