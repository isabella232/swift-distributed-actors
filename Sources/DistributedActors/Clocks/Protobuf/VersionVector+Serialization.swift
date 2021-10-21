//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2019-2020 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import _Distributed

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: ReplicaID

extension ReplicaID: ProtobufRepresentable {
    public typealias ProtobufRepresentation = ProtoVersionReplicaID

    public func toProto(context: Serialization.Context) throws -> ProtoVersionReplicaID {
        var proto = ProtoVersionReplicaID()
        switch self.storage {
        case .actorAddress(let actorAddress):
            proto.actorAddress = try actorAddress.toProto(context: context)
        case .actorIdentity(let actorIdentity):
            proto.actorIdentity = try actorIdentity.toProto(context: context)
        case .uniqueNode(let node):
            proto.uniqueNode = try node.toProto(context: context)
        case .uniqueNodeID(let nid):
            proto.uniqueNodeID = nid.value
        }
        return proto
    }

    public init(fromProto proto: ProtoVersionReplicaID, context: Serialization.Context) throws {
        guard let value = proto.value else {
            throw SerializationError.missingField("value", type: String(describing: ReplicaID.self))
        }

        switch value {
        case .actorAddress(let protoActorAddress):
            let actorAddress = try ActorAddress(fromProto: protoActorAddress, context: context)
            self = .actorAddress(actorAddress)
        case .actorIdentity(let protoIdentity):
            let id = try AnyActorIdentity(fromProto: protoIdentity, context: context)
            self = .actorIdentity(id)
        case .uniqueNode(let protoNode):
            let node = try UniqueNode(fromProto: protoNode, context: context)
            self = .uniqueNode(node)
        case .uniqueNodeID(let nid):
            self = .uniqueNodeID(nid)
        }
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: VersionVector

extension VersionVector: ProtobufRepresentable {
    public typealias ProtobufRepresentation = ProtoVersionVector

    public func toProto(context: Serialization.Context) throws -> ProtoVersionVector {
        var proto = ProtoVersionVector()

        let replicaVersions: [ProtoReplicaVersion] = try self.state.map { replicaID, version in
            var replicaVersion = ProtoReplicaVersion()
            replicaVersion.replicaID = try replicaID.toProto(context: context)
            replicaVersion.version = UInt64(version)
            return replicaVersion
        }
        proto.state = replicaVersions

        return proto
    }

    /// Serialize using uniqueNodeID specifically (or crash);
    /// Used in situations where an enclosing message already has the unique nodes serialized and we can save space by avoiding to serialize them again.
    public func toCompactReplicaNodeIDProto(context: Serialization.Context) throws -> ProtoVersionVector {
        var proto = ProtoVersionVector()

        let replicaVersions: [ProtoReplicaVersion] = try self.state.map { replicaID, version in
            var replicaVersion = ProtoReplicaVersion()
            switch replicaID.storage {
            case .uniqueNode(let node):
                replicaVersion.replicaID.uniqueNodeID = node.nid.value
            case .uniqueNodeID(let nid):
                replicaVersion.replicaID.uniqueNodeID = nid.value
            case .actorAddress:
                throw SerializationError.unableToSerialize(hint: "Can't serialize using actor address as replica id! Was: \(replicaID)")
            case .actorIdentity:
                throw SerializationError.unableToSerialize(hint: "Can't serialize using actor identity as replica id! Was: \(replicaID)")
            }
            replicaVersion.version = UInt64(version)
            return replicaVersion
        }
        proto.state = replicaVersions

        return proto
    }

    public init(fromProto proto: ProtoVersionVector, context: Serialization.Context) throws {
        // `state` defaults to [:]
        self.state.reserveCapacity(proto.state.count)

        for replicaVersion in proto.state {
            guard replicaVersion.hasReplicaID else {
                throw SerializationError.missingField("replicaID", type: String(describing: ReplicaVersion.self))
            }
            let replicaID = try ReplicaID(fromProto: replicaVersion.replicaID, context: context)
            state[replicaID] = replicaVersion.version
        }
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: VersionDot

extension VersionDot: ProtobufRepresentable {
    public typealias ProtobufRepresentation = ProtoVersionDot

    public func toProto(context: Serialization.Context) throws -> ProtoVersionDot {
        var proto = ProtoVersionDot()
        proto.replicaID = try self.replicaID.toProto(context: context)
        proto.version = UInt64(self.version)
        return proto
    }

    public init(fromProto proto: ProtoVersionDot, context: Serialization.Context) throws {
        guard proto.hasReplicaID else {
            throw SerializationError.missingField("replicaID", type: String(describing: VersionDot.self))
        }
        self.replicaID = try ReplicaID(fromProto: proto.replicaID, context: context)
        self.version = proto.version
    }
}
