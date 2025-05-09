import 'package:bluesky/bluesky.dart' as bsky;

const maxPostsToLoad = 200;
const fetchSize = 100;

class UiException implements Exception {
  final String message;

  UiException(this.message);

  @override
  String toString() {
    return message;
  }
}

class AccountReference {
  final String login;
  String did;

  AccountReference(this.login, this.did);

  AccountReference.fromJson(Map<String, dynamic> json)
      : login = json['login'],
        did = json['did'] ?? '';

  Map<String, dynamic> toJson() => {
        'login': login,
        'did': did,
      };
}

class Profile {
  final String did;
  final String handle;
  final String? displayName;
  final String? avatar;

  Profile(this.did, this.handle, this.displayName, this.avatar);

  static Profile fromActorProfile(bsky.ActorProfile actorProfile) {
    return Profile(actorProfile.did, actorProfile.handle,
        actorProfile.displayName, actorProfile.avatar);
  }

  static Profile fromActor(dynamic actor) {
    var displayName = actor.displayName;
    if (displayName == null || displayName.isEmpty) {
      displayName = null;
    }
    return Profile(actor.did, actor.handle, displayName, actor.avatar);
  }

  String sortName() {
    return (displayName ?? handle).toLowerCase();
  }

  @override
  String toString() {
    return "Profile(did: $did, handle: $handle, displayName: $displayName, avatar: $avatar)";
  }
}

enum PostType {
  post,
  repost,
  replyToFriend,
  reply,
}

const postTypeNames = {
  PostType.post: "Post",
  PostType.reply: "Reply to anybody",
  PostType.replyToFriend: "Reply to somebody you follow",
  PostType.repost: "Repost",
};

class Post {
  PostType type;
  String eventUser;
  String sourceAuthor;
  String message;
  String hash;
  DateTime createdAt;

  Post(this.type, this.eventUser, this.sourceAuthor, this.message, this.hash,
      this.createdAt);

  static Post fromFeedView(bsky.FeedView feedView) {
    var eventUser = feedView.post.author.handle;
    final sourceAuthor = feedView.post.author.handle;
    var postType = PostType.post;
    if (feedView.post.record.reply != null) {
      postType = PostType.reply;
    } else if (feedView.reason?.data is bsky.ReasonRepost) {
      postType = PostType.repost;
      final reason = feedView.reason!.data as bsky.ReasonRepost;
      eventUser = reason.by.handle;
    }
    return Post(
      postType,
      eventUser,
      sourceAuthor,
      feedView.post.record.text,
      feedView.post.uri.toString().split('/').last,
      feedView.post.record.createdAt,
    );
  }

  @override
  String toString() {
    return "Post(type: $type, eventUser: $eventUser, sourceAuthor: $sourceAuthor, message: $message, hash: $hash, createdAt: $createdAt)";
  }
}

class BlueskyService {
  final bsky.Bluesky _bluesky;

  BlueskyService(this._bluesky);

  static Future<BlueskyService> getPublicConnection() async {
    final bluesky = bsky.Bluesky.anonymous(service: "public.api.bsky.app");
    return BlueskyService(bluesky);
  }

  Future<List<Post>> getPostsFromAuthor(String author, DateTime since) async {
    final List<Post> results = [];
    var remainingPosts = maxPostsToLoad;
    String? cursor;
    while (true) {
      final feed = await _bluesky.feed
          .getAuthorFeed(actor: author, cursor: cursor, limit: fetchSize);
      cursor = feed.data.cursor;
      final posts =
          feed.data.feed.map((raw) => Post.fromFeedView(raw)).toList();
      if (posts.isEmpty) {
        break;
      }
      for (var post in posts) {
        remainingPosts--;
        if (remainingPosts < 0) {
          return results;
        }
        if (post.createdAt.isBefore(since)) {
          return results;
        }
        results.insert(0, post);
      }
      if (cursor == null) {
        break;
      }
    }
    return results;
  }

  Future<Profile> getProfile(String name) async {
    final profile = await _bluesky.actor.getProfile(actor: name);
    return Profile.fromActorProfile(profile.data);
  }

  Future<List<Profile>> getFollowingForUser(String name) async {
    final List<Profile> following = [];
    String? cursor;
    while (true) {
      final results = await _bluesky.graph
          .getFollows(actor: name, cursor: cursor, limit: fetchSize);
      cursor = results.data.cursor;
      if (results.data.follows.isEmpty) {
        break;
      }
      for (var actor in results.data.follows) {
        following.add(Profile.fromActor(actor));
      }
      if (cursor == null) {
        break;
      }
    }
    return following;
  }

  Future<int> getFollowingCountForUser(String name) async {
    final results = await _bluesky.actor.getProfile(actor: name);
    return results.data.followsCount;
  }

  Future<List<Profile>> searchUsers(String query) async {
    if (query.isEmpty) {
      return [];
    }
    var results =
        await _bluesky.actor.searchActorsTypeahead(term: query, limit: 10);
    return results.data.actors
        .map((actor) => Profile.fromActor(actor))
        .toList();
  }
}
