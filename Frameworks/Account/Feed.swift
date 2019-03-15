//
//  Feed.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb
import Articles
import RSDatabase

public final class Feed: DisplayNameProvider, Renamable, UnreadCountProvider, Hashable {

	private struct Key {
		static let url = "url"
		static let feedID = "feedID"
		static let homePageURL = "homePageURL"
		static let iconURL = "iconURL"
		static let faviconURL = "faviconURL"
		static let name = "name"
		static let editedName = "editedName"
		static let authors = "authors"
		static let conditionalGetInfo = "conditionalGetInfo"
		static let conditionalGetLastModified = "lastModified"
		static let conditionalGetEtag = "etag"
		static let contentHash = "contentHash"
	}

	public weak var account: Account?
	public let url: String
	public let feedID: String

	public var homePageURL: String? {
		get {
			return metadata?.homePageURL
		}
		set {
			if let url = newValue {
				metadata?.homePageURL = url.rs_normalizedURL()
			}
			else {
				metadata?.homePageURL = nil
			}
		}
	}

	public var iconURL: String? {
		get {
			return metadata?.iconURL
		}
		set {
			metadata?.iconURL = newValue
		}
	}

	public var faviconURL: String? {
		get {
			return metadata?.faviconURL
		}
		set {
			metadata?.faviconURL = newValue
		}
	}

	public var name: String? {
		get {
			return metadata?.name
		}
		set {
			let oldNameForDisplay = nameForDisplay
			metadata?.name = newValue
			if oldNameForDisplay != nameForDisplay {
				postDisplayNameDidChangeNotification()
			}
		}
	}

	public var authors: Set<Author>? {
		get {
			if let authorsArray = metadata?.authors {
				return Set(authorsArray)
			}
			return nil
		}
		set {
			if let authorsSet = newValue {
				metadata?.authors = Array(authorsSet)
			}
			else {
				metadata?.authors = nil
			}
		}
	}

	public var editedName: String? {
		// Don’t let editedName == ""
		get {
			guard let s = metadata?.editedName, !s.isEmpty else {
				return nil
			}
			return s
		}
		set {
			if newValue != editedName {
				if let valueToSet = newValue, !valueToSet.isEmpty {
					metadata?.editedName = valueToSet
				}
				else {
					metadata?.editedName = nil
				}
				postDisplayNameDidChangeNotification()
			}
		}
	}

	public var conditionalGetInfo: HTTPConditionalGetInfo? {
		get {
			return metadata?.conditionalGetInfo
		}
		set {
			metadata?.conditionalGetInfo = newValue
		}
	}

	public var contentHash: String? {
		get {
			return metadata?.contentHash
		}
		set {
			metadata?.contentHash = newValue
		}
	}

	// MARK: - DisplayNameProvider

	public var nameForDisplay: String {
		if let s = editedName, !s.isEmpty {
			return s
		}
		if let s = name, !s.isEmpty {
			return s
		}
		return NSLocalizedString("Untitled", comment: "Feed name")
	}

	// MARK: - Renamable

	public func rename(to newName: String) {
		editedName = newName
	}

	// MARK: - UnreadCountProvider
	
	public var unreadCount: Int {
		get {
			return account?.unreadCount(for: self) ?? 0
		}
		set {
			if unreadCount == newValue {
				return
			}
			account?.setUnreadCount(newValue, for: self)
			postUnreadCountDidChangeNotification()
		}
	}

	private let accountID: String // Used for hashing and equality; account may turn nil

	private var _metadata: FeedMetadata?
	private var metadata: FeedMetadata? {
		if let cachedMetadata = _metadata {
			return cachedMetadata
		}
		_metadata = account?.metadata(for: self)
		return _metadata
	}

	// MARK: - Init

	public init(account: Account, url: String, feedID: String) {
		self.account = account
		self.accountID = account.accountID
		self.url = url
		self.feedID = feedID
	}

	// MARK: - Disk Dictionary

	convenience public init?(account: Account, dictionary: [String: Any]) {

		guard let url = dictionary[Key.url] as? String else {
			return nil
		}
		let feedID = dictionary[Key.feedID] as? String ?? url
		
		self.init(account: account, url: url, feedID: feedID)
		self.editedName = dictionary[Key.editedName] as? String
		self.name = dictionary[Key.name] as? String
	}

	public static func isFeedDictionary(_ d: [String: Any]) -> Bool {

		return d[Key.url] != nil
	}

	// MARK: - Debug

	public func debugDropConditionalGetInfo() {

		conditionalGetInfo = nil
		contentHash = nil
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(feedID)
		hasher.combine(accountID)
	}

	// MARK: - Equatable

	public class func ==(lhs: Feed, rhs: Feed) -> Bool {

		return lhs.feedID == rhs.feedID && lhs.accountID == rhs.accountID
	}
}

// MARK: - OPMLRepresentable

extension Feed: OPMLRepresentable {

	public func OPMLString(indentLevel: Int) -> String {
		// https://github.com/brentsimmons/NetNewsWire/issues/527
		// Don’t use nameForDisplay because that can result in a feed name "Untitled" written to disk,
		// which NetNewsWire may take later to be the actual name.
		var nameToUse = editedName
		if nameToUse == nil {
			nameToUse = name
		}
		if nameToUse == nil {
			nameToUse = ""
		}
		let escapedName = nameToUse!.rs_stringByEscapingSpecialXMLCharacters()
		
		var escapedHomePageURL = ""
		if let homePageURL = homePageURL {
			escapedHomePageURL = homePageURL.rs_stringByEscapingSpecialXMLCharacters()
		}
		let escapedFeedURL = url.rs_stringByEscapingSpecialXMLCharacters()

		var s = "<outline text=\"\(escapedName)\" title=\"\(escapedName)\" description=\"\" type=\"rss\" version=\"RSS\" htmlUrl=\"\(escapedHomePageURL)\" xmlUrl=\"\(escapedFeedURL)\"/>\n"
		s = s.rs_string(byPrependingNumberOfTabs: indentLevel)

		return s
	}
}

extension Set where Element == Feed {

	func feedIDs() -> Set<String> {

		return Set<String>(map { $0.feedID })
	}
}
