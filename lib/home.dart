import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/material.dart';
import 'package:fritter/client.dart';
import 'package:fritter/database/entities.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'home_model.dart';
import 'options.dart';
import 'tweet.dart';
import 'user.dart';

class _Tab {
  final String title;
  final IconData icon;

  _Tab(this.title, this.icon);
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final List<_Tab> _tabs = [
    _Tab('Trending', Icons.trending_up),
    _Tab('Following', Icons.people),
  ];
  
  late TabController _tabController;
  late int _currentTabIndex;

  @override
  void initState() {
    super.initState();

    _currentTabIndex = 0;

    _tabController = TabController(vsync: this, length: _tabs.length);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

 @override
 void dispose() {
   _tabController.dispose();
   super.dispose();
 }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentTabIndex].title),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: TweetSearch());
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => OptionsScreen()));
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            ..._tabs.map((e) => Tab(
              icon: Icon(e.icon),
            ))
          ]
        ),
      ),
      body: ChangeNotifierProvider(
        create: (context) => HomeModel(),
        child: TabBarView(
          controller: _tabController,
          children: [
            TrendsContent(),
            FollowingContent(),
          ],
        ),
      ),
    );
  }
}

typedef ItemWidgetBuilder<T> = Widget Function(BuildContext context, T item);

class TweetSearchResultList<T> extends StatelessWidget {

  final AsyncSnapshot<List<T>> snapshot;
  final ItemWidgetBuilder<T> itemBuilder;

  const TweetSearchResultList({Key? key, required this.snapshot, required this.itemBuilder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      var error = snapshot.error as Exception;

      return Container(
        margin: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Oops! Something went wrong 🥲', style: TextStyle(
                fontSize: 18
            )),
            Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              child: Text('$error', style: TextStyle(
                  color: Theme.of(context).hintColor
              )),
            )
          ],
        ),
      );
    }

    var items = snapshot.data;
    if (items == null) {
      return Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(child: Text('No results'));
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, index) {
        return itemBuilder(context, items[index]);
      },
    );
  }
}


class TweetSearch extends SearchDelegate {
  Future<List<Tweet>> searchTweets(BuildContext context, String query) async {
    if (query.isEmpty) {
      return [];
    } else {
      return await Twitter.searchTweets(query);
    }
  }

  Future<List<User>> searchUsers(BuildContext context, String query) async {
    if (query.isEmpty) {
      return [];
    } else {
      return await Twitter.searchUsers(query);
    }
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: Icon(Icons.clear), onPressed: () {
        query = '';
      })
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(icon: AnimatedIcons.menu_arrow, progress: transitionAnimation),
      onPressed: () {
        close(context, null);
      }
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            child: TabBar(tabs: [
              Tab(icon: Icon(Icons.person)),
              Tab(icon: Icon(Icons.comment)),
            ]),
          ),
          Container(
            child: Expanded(child: TabBarView(children: [
              FutureBuilder<List<User>>(
                future: searchUsers(context, query),
                builder: (context, snapshot) {
                  return TweetSearchResultList<User>(snapshot: snapshot, itemBuilder: (context, item) {
                    return UserTile(
                        id: item.idStr!,
                        name: item.name!,
                        imageUri: item.profileImageUrlHttps!,
                        screenName: item.screenName!
                    );
                  });
                },
              ),
              FutureBuilder<List<Tweet>>(
                future: searchTweets(context, query),
                builder: (context, snapshot) {
                  return TweetSearchResultList<Tweet>(snapshot: snapshot, itemBuilder: (context, item) {
                    return TweetTile(
                      tweet: item,
                      clickable: true
                    );
                  });
                },
              ),
            ])),
          )
        ],
      )
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }

}

class TrendsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Consumer<HomeModel>(
        builder: (context, model, child) {
          return FutureBuilder<List<Trends>>(
            future: model.loadTrends(),
            builder: (context, snapshot) {
              var data = snapshot.data;
              if (data == null) {
                return Center(child: CircularProgressIndicator());
              }

              var trends = data[0].trends;
              if (trends == null) {
                return Text('There were no trends returned. This is unexpected! Please report as a bug, if possible.');
              }

              var numberFormat = NumberFormat.compact();

              return ListView(
                children: [
                  Container(
                    child: ListTile(
                      title: Text('Worldwide trends', style: TextStyle(
                          fontWeight: FontWeight.bold
                      )),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: ScrollPhysics(),
                    itemCount: trends.length,
                    itemBuilder: (context, index) {
                      var trend = trends[index];

                      return ListTile(
                        dense: true,
                        leading: Text('${++index}'),
                        title: Text('${trend.name!}'),
                        subtitle: trend.tweetVolume == null
                            ? null
                            : Text('${numberFormat.format(trend.tweetVolume)} tweets'),
                        onTap: () async {
                          await showSearch(
                              context: context,
                              delegate: TweetSearch(),
                              query: Uri.decodeQueryComponent(trend.query!)
                          );
                        },
                      );
                    },
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class FollowingContent extends StatefulWidget {
  @override
  _FollowingContentState createState() => _FollowingContentState();
}

class _FollowingContentState extends State<FollowingContent> {
  final _refreshController = RefreshController(initialRefresh: false);

  Future _onRefresh() async {
    try {
      await Future.delayed(Duration(milliseconds: 400));

      await context.read<HomeModel>().refresh();
    } finally {
      _refreshController.refreshCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Consumer<HomeModel>(
        builder: (context, model, child) {
          return FutureBuilder<List<Following>>(
            future: model.listFollowing(),
            builder: (context, snapshot) {
              var data = snapshot.data;
              if (data == null) {
                return Center(child: CircularProgressIndicator());
              }

              if (data.isEmpty) {
                return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('¯\\_(ツ)_/¯', style: TextStyle(
                          fontSize: 32
                      )),
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Try searching for some users to follow!', style: TextStyle(
                            color: Theme.of(context).hintColor
                        )),
                      )
                    ])
                );
              }

              return SmartRefresher(
                controller: _refreshController,
                enablePullDown: true,
                enablePullUp: false,
                onRefresh: _onRefresh,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    var user = data[index];

                    return UserTile(
                      id: user.id.toString(),
                      name: user.name,
                      screenName: user.screenName,
                      imageUri: user.profileImageUrlHttps,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
