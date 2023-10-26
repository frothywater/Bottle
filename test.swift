import Foundation

struct Post: Decodable, Identifiable {
    let id: String
    let community: String
    let user: User?
    let text: String
    let media: [Media]
    let createdDate: Date
    let addedDate: Date
}

struct User: Decodable {
    let id: String?
    let name: String?
    let username: String?
    let avatarUrl: String?
    let description: String?
    let url: String?
}

struct Media: Decodable, Identifiable {
    let id: String
    let url: String
    let width: Int
    let height: Int
    let thumbnailUrl: String?
}

struct Pagination<T: Decodable>: Decodable {
    let items: [T]
    let page: Int
    let pageSize: Int
    let totalItems: Int
    let totalPages: Int
}

let s = """
{
   "items" : [
      {
         "added_date" : "2023-08-30T14:12:04",
         "community" : "twitter",
         "created_date" : "2023-05-20T03:16:58",
         "id" : "1659760095151132673",
         "media" : [
            {
               "height" : 2048,
               "id" : "3_1659760087609774081",
               "thumbnail_url" : null,
               "url" : "https://pbs.twimg.com/media/FwinAYJaEAE2iif.jpg",
               "width" : 1472
            }
         ],
         "text" : "ひとやすみ　#初音ミク https://t.co/nrqWhe1LV5",
         "user" : {
            "avatar_url" : "https://pbs.twimg.com/profile_images/1621473194560610308/0tkwwA_-_normal.jpg",
            "description" : "(ﾀnanuki)無断転載・無断使用・AI学習禁止。Repost is prohibited. ○skeb→ https://t.co/5W3PbOJPhw",
            "id" : "1374665331361210368",
            "name" : "たなぬき",
            "url" : "https://t.co/jAhiOpAyhQ",
            "username" : "nknk_fff"
         }
      }
   ],
   "page" : 0,
   "page_size" : 1,
   "total_items" : 11556,
   "total_pages" : 11556
}
"""

let data = s.data(using: .utf8)!
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .formatted(formatter)
let result = try decoder.decode(Pagination<Post>.self, from: data)
