//
//  PlaylistModel.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/9.
//

import SwiftUI
import Alamofire
import SwiftyJSON

actor PlayListModel {
    struct PlayListDeatil {
        var id = UUID()
        var basic:PlayListObj
        var songs:[PlayListSong]
    }
    struct PlayListSong:Identifiable {
        var id = UUID()
        var songID:String
        var name:String
        var artist:String
        var imageURL:URL
    }
    let session:Session = AlaCache.createCachebleAlamofire(diskPath: "YiPlayListURLCache")
    enum PlaylistTimeoutError:Error,LocalizedError {
        case toBigPlaylist
        var errorDescription: String? {
            switch self {
            case .toBigPlaylist:
                "歌单内音乐数量过多，建议您在手机上将想在Apple Watch上听的音乐拆分到一个单独的歌单里"
            }
        }
    }
    func getPlaylistDetail(playlist:PlayListObj,useCache:Bool) async throws -> (PlayListDeatil,haveMore:Bool) {
        let playlistID = playlist.playListID
        let route = "/playlist/detail"
        let fullURL = baseAPI + route
        //重写超时错误
        let json = try await {
            do {
                let res = try await session.request(URLRequest.create(fullURL, parameters: ["id":playlistID] as [String:String], cachePolicy: useCache ? .returnCacheDataElseLoad : .reloadIgnoringLocalAndRemoteCacheData)).LSAsyncJSON()
                return res
            } catch {
                let error = error as NSError
                if error.code == NSURLErrorTimedOut {
                    throw PlaylistTimeoutError.toBigPlaylist
                } else {
                    throw error
                }
            }
        }()
        try json.errorCheck()
//        guard let trackCount = json["playlist"]["trackCount"].int64 else {
//            throw getPlaylistDetailError.noTrackCount
//        }
        guard let tracks = json["playlist"]["tracks"].array else {
            throw getPlaylistDetailError.noTracks
        }
        guard let trackIDs = json["playlist"]["trackIds"].array else {
            throw getPlaylistDetailError.noTrackIds
        }
        print("歌单内一共有\(trackIDs.count)首歌")
        print("需要处理\(tracks.count)首歌")
        let haveMore = trackIDs.count > tracks.count
        //使用TaskGroup并行化处理，在歌单内歌曲数量很多的时候可以显著提升速度
        let mappedSongs: [PlayListSong] = try await withThrowingTaskGroup(of: PlayListSong?.self) { group in
            for item in tracks {
                group.addTask {
                    return try await self.parseSong(item: item)
                }
            }

            var results: [PlayListSong] = []
            for try await result in group {
                if let song = result {
                    results.append(song)
                }
            }
            return results
        }
        return (.init(basic: playlist, songs: mappedSongs),haveMore)
    }
    func parseSong(item: JSON) throws -> PlayListSong {
        guard let name = item["name"].string else {
            throw getPlaylistDetailError.noMusicName
        }
        guard let idRaw = item["id"].int64 else {
            throw getPlaylistDetailError.noMusicID
        }
        let id = String(idRaw)
        guard let picUrl = item["al"]["picUrl"].url else {
            throw getPlaylistDetailError.noMusicURL
        }
        let artist: String = {
            var allArtistName: [String] = []
            if let artistsList = item["ar"].array {
                for artist in artistsList {
                    if let name = artist["name"].string {
                        allArtistName.append(name)
                    }
                }
            }
            if !allArtistName.isEmpty {
                return allArtistName.joined(separator: "/")
            } else {
                if let cloudStorageMusic = item["pc"]["artist"].string {
                    return cloudStorageMusic
                }
            }
            return "未知作者"
        }()
        return PlayListSong(songID: id, name: name, artist: artist, imageURL: picUrl)
    }

    enum getPlaylistDetailError:Error,LocalizedError {
        case noTracks
        case noMusicName
        case noMusicID
        case noMusicURL
        case noTrackCount
        case noTrackIds
        var errorDescription: String? {
            switch self {
            case .noTrackIds:
                "获取歌单详情失败（trackIds字段缺失）"
            case .noTrackCount:
                "获取歌单详情失败（trackCount字段缺失）"
            case .noMusicURL:
                "获取歌单详情失败（picUrl字段缺失）"
            case .noMusicID:
                "获取歌单详情失败（id字段缺失）"
            case .noTracks:
                "获取歌单详情失败（track字段缺失）"
            case .noMusicName:
                "获取歌单详情失败（name字段缺失）"
            }
        }
    }
    func getMyPlayList(user:YiUser) async throws -> PlayListResponse {
        let route = "/user/playlist"
        let fullURL = baseAPI + route
        print("fullURL:\(fullURL)")
        let json = try await AF.request(fullURL,parameters: ["uid":user.userID,"timestamp":String(Int64(Date.now.timeIntervalSince1970))] as [String:String]).LSAsyncJSON()
        print("UserID:\(user.userID)")
        try json.errorCheck()
        print("getMyPlayList\(json)")
        return try PlayListResponse.parse(json)
    }
    
    struct PlayListResponse:Identifiable,Equatable {
        var id = UUID()
        var playlists:[PlayListObj]
        static
        func parse(_ json:JSON) throws -> Self {
            guard let plArray = json["playlist"].array else {
                throw PlayListResponseError.array
            }
            let mappedArray = try plArray.map { json in
                return try PlayListObj.parse(json)
            }
            return PlayListResponse(playlists:mappedArray)
        }
        enum PlayListResponseError:Error,LocalizedError {
            case array
            var errorDescription: String? {
                switch self {
                case .array:
                    "获取歌单失败（playlist字段缺失）"
                }
            }
        }
    }
    struct PlayListObj:Identifiable,Equatable,Hashable {
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        var id = UUID()
        var playListID:String
        var name:String
        var description:String
        var updateAt:Date
        var coverImgUrl:URL?
        var creator:YiOnlineUser
        static
        func parse(_ json:JSON) throws -> Self {
            guard let updateTime = json["updateTime"].int64 else {
                throw PlayListObjParseError.updateTime
            }
            guard let image = json["coverImgUrl"].url else {
                throw PlayListObjParseError.image
            }
            guard let name = json["name"].string else {
                throw PlayListObjParseError.name
            }
            guard let id = json["id"].int64 else {
                throw PlayListObjParseError.id
            }
            let creatorJson = json["creator"]
            let creator = try YiOnlineUser.parse(creatorJson)
            return PlayListObj(playListID: String(id), name: name, description: "", updateAt: Date(timeIntervalSince1970:  TimeInterval(updateTime)), coverImgUrl: image, creator: creator)
        }
    }
    enum PlayListObjParseError:Error,LocalizedError {
        case updateTime
        case image
        case name
        case id
        case noCreator
        var errorDescription: String? {
            switch self {
            case .updateTime:
                "获取歌单失败（updateTime字段缺失）"
            case .image:
                "获取歌单失败（coverImgUrl字段缺失）"
            case .name:
                "获取歌单失败（name字段缺失）"
            case .id:
                "获取歌单失败（id字段缺失）"
            case .noCreator:
                "获取歌单失败（creator字段缺失）"
            }
        }
    }
}

@Observable
class MyPlayListViewModel:Hashable {
    static func == (lhs: MyPlayListViewModel, rhs: MyPlayListViewModel) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    var id = UUID()
    var playListContainer:PlayListModel.PlayListResponse
    init(playList: PlayListModel.PlayListResponse) {
        self.playListContainer = playList
    }
}

struct YiOnlineUser:Identifiable,Equatable {
    var id = UUID()
    var userID:String
    var nickName:String? = nil
    var avatarImgURL:URL? = nil
    static
    func parse(_ json:JSON) throws -> Self {
        guard let userId = json["userId"].int64 else {
            throw YiOnlineUserParseError.id
        }
        let name = json["nickname"].string
        
        let avatarUrl = json["avatarUrl"].url
        return YiOnlineUser(userID: String(userId), nickName: name, avatarImgURL: avatarUrl)
    }
    enum YiOnlineUserParseError:Error,LocalizedError {
        case name
        case id
        case avatarUrl
        var errorDescription: String? {
            switch self {
            case .name:
                "获取歌单失败（nickname字段缺失）"
            case .id:
                "获取歌单失败（userId字段缺失）"
            case .avatarUrl:
                "获取歌单失败（avatarUrl字段缺失）"
            }
        }
    }
}
