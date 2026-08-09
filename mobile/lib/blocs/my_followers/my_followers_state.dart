// ABOUTME: State class for MyFollowersBloc
// ABOUTME: Represents all possible states of the current user's followers list

part of 'my_followers_bloc.dart';

/// Enum representing the status of the followers list loading
enum MyFollowersStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading data from Nostr
  loading,

  /// Data loaded successfully
  success,

  /// An error occurred while loading data
  failure,
}

/// State class for MyFollowersBloc
final class MyFollowersState extends Equatable {
  const MyFollowersState({
    this.status = MyFollowersStatus.initial,
    this.followersPubkeys = const [],
    this.rawFollowersPubkeys = const [],
    this.authoritativeFollowerCount = 0,
    this.isRefreshing = false,
  });

  /// The current status of the followers list
  final MyFollowersStatus status;

  /// List of pubkeys who follow the current user (blocklist-filtered).
  final List<String> followersPubkeys;

  /// Unfiltered follower pubkeys as received from the repository.
  ///
  /// Stored in state so blocklist re-filtering can replay the full list
  /// without waiting for a new network event.
  final List<String> rawFollowersPubkeys;

  /// Follower count as reported by the repository, before any local
  /// blocklist filtering.
  ///
  /// Kept verbatim rather than derived from [followerCount] so re-filtering
  /// stays exact: reconstructing it by inverting a previous [followerCount]
  /// emission is only correct when that emission did not clamp to the visible
  /// list length.
  final int authoritativeFollowerCount;

  /// Visible follower count after applying local blocklist filters.
  ///
  /// Downloading all kind 3 events is limited by relay result caps, so
  /// [authoritativeFollowerCount] may exceed the number of pubkeys actually
  /// fetched. Followers we know are hidden locally are subtracted from it, and
  /// the result never drops below the number of followers on screen.
  int get followerCount => visibleFollowerCount(
    visiblePubkeyCount: followersPubkeys.length,
    rawPubkeyCount: rawFollowersPubkeys.length,
    authoritativeFollowerCount: authoritativeFollowerCount,
  );

  /// True while cached data is shown but a fresh network fetch is in progress.
  final bool isRefreshing;

  /// Create a copy with updated values
  MyFollowersState copyWith({
    MyFollowersStatus? status,
    List<String>? followersPubkeys,
    List<String>? rawFollowersPubkeys,
    int? authoritativeFollowerCount,
    bool? isRefreshing,
  }) {
    return MyFollowersState(
      status: status ?? this.status,
      followersPubkeys: followersPubkeys ?? this.followersPubkeys,
      rawFollowersPubkeys: rawFollowersPubkeys ?? this.rawFollowersPubkeys,
      authoritativeFollowerCount:
          authoritativeFollowerCount ?? this.authoritativeFollowerCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    followersPubkeys,
    rawFollowersPubkeys,
    authoritativeFollowerCount,
    isRefreshing,
  ];
}
