import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koukoku_ads/COMPONENTS/asyncimage_view.dart';
import 'package:koukoku_ads/COMPONENTS/button_view.dart';
import 'package:koukoku_ads/COMPONENTS/future_view.dart';
import 'package:koukoku_ads/COMPONENTS/image_view.dart';
import 'package:koukoku_ads/COMPONENTS/main_view.dart';
import 'package:koukoku_ads/COMPONENTS/padding_view.dart';
import 'package:koukoku_ads/COMPONENTS/roundedcorners_view.dart';
import 'package:koukoku_ads/COMPONENTS/text_view.dart';
import 'package:koukoku_ads/FUNCTIONS/colors.dart';
import 'package:koukoku_ads/FUNCTIONS/location.dart';
import 'package:koukoku_ads/FUNCTIONS/misc.dart';
import 'package:koukoku_ads/FUNCTIONS/nav.dart';
import 'package:koukoku_ads/MODELS/DATAMASTER/datamaster.dart';
import 'package:koukoku_ads/MODELS/constants.dart';
import 'package:koukoku_ads/MODELS/firebase.dart';
import 'package:koukoku_ads/MODELS/geohash.dart';
import 'package:koukoku_ads/VIEWS/filters.dart';
import 'package:koukoku_ads/VIEWS/login.dart';
import 'package:koukoku_ads/MODELS/screen.dart';
import 'package:koukoku_ads/VIEWS/profile.dart';
import 'package:koukoku_ads/VIEWS/user_business_profile.dart';
import 'package:visibility_detector/visibility_detector.dart';

class UserBrowse extends StatefulWidget {
  final DataMaster dm;
  const UserBrowse({super.key, required this.dm});

  @override
  State<UserBrowse> createState() => _UserBrowseState();
}

class _UserBrowseState extends State<UserBrowse> {
  // Pagination handling
  dynamic lastDoc;
  List<dynamic> ads = [];
  bool isLoading = false;
  int limit = 60;
  bool _noMore = false;
  List<dynamic> _seenAdIds = [];

  Future<void> _fetchLocalAds() async {
    if (lastDoc == null) {
      ads = [];
    }
    try {
      // UPDATE THINGS
      final needsUpdated = await firebase_GetAllDocumentsQueriedLimited(
          '${appName}_Campaigns',
          [
            {'field': 'active', 'operator': '==', 'value': true},
            {
              'field': 'expDate',
              'operator': '<',
              'value': DateTime(DateTime.now().year, DateTime.now().month,
                      DateTime.now().day, 11, 59, 59)
                  .millisecondsSinceEpoch
            },
            {'field': 'expDate', 'operator': '!=', 'value': 0},
            {'field': 'isCoupon', 'operator': '==', 'value': true}
          ],
          50);
      for (var doc in needsUpdated) {
        await firebase_UpdateDocument(
            '${appName}_Campaigns', doc['id'], {'active': false});
        print('Ad ${doc['id']} has just been updated.');
      }

      // Fetch documents from Firebase with pagination
      var docs;
      List<Map<String, dynamic>> filters = [
        {'field': 'active', 'operator': '==', 'value': true},
      ];

      if (widget.dm.user['category'] != null &&
          widget.dm.user['category'] != '') {
        filters.add({
          'field': 'category',
          'operator': '==',
          'value': widget.dm.user['category'],
        });
      }

      print(filters);

      // Ensure the distance is a double
      final distance = (widget.dm.user['distance'] ?? 30).toDouble();

      docs = await firebase_GetAllDocumentsQueriedLimitedDistanced(
        '${appName}_Campaigns',
        filters,
        limit,
        geohash: widget.dm.user['geohash'],
        distance: distance,
        lastDoc: lastDoc,
      );

      if (docs.isNotEmpty) {
        setState(() {
          lastDoc = docs.last?['doc']; // Update lastDoc for pagination
          ads.addAll(docs); // Append new ads to the existing list
        });
      } else if (docs.isEmpty || docs.length < limit) {
        setState(() {
          _noMore = true;
        });
      }
    } catch (error) {
      print('Error fetching ads: $error');
    } finally {
      setState(() {
        isLoading = false; // Always reset loading state
      });
    }
  }

  List<Widget> buildAdWidgets(BuildContext context, List<dynamic> ads) {
    List<Widget> widgets = [];

    for (int i = 0; i < ads.length; i++) {
      Widget adWidget; // Declare adWidget here

      // Build the ad widget based on its chosen option
      if (ads[i]['chosenOption'] == '2 x 2') {
        adWidget = AsyncImageView(
          radius: 10,
          imagePath: ads[i]['imagePath'],
          width: getWidth(context),
          height: getWidth(context),
          objectFit: BoxFit.fill,
        );
      } else if (ads[i]['chosenOption'] == '2 x 1') {
        adWidget = AsyncImageView(
          radius: 10,
          imagePath: ads[i]['imagePath'],
          width: getWidth(context),
          height: getWidth(context) / 2,
          objectFit: BoxFit.fill,
        );
      } else if (ads[i]['chosenOption'] == '1 x 1' &&
          i + 1 < ads.length &&
          ads[i + 1]['chosenOption'] == '1 x 1') {
        // Add two consecutive '1 x 1' ads side by side
        adWidget = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: AsyncImageView(
                radius: 10,
                imagePath: ads[i]['imagePath'],
                width: getWidth(context) / 2,
                height: getWidth(context) / 2,
                objectFit: BoxFit.fill,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AsyncImageView(
                radius: 10,
                imagePath: ads[i + 1]['imagePath'],
                width: getWidth(context) / 2,
                height: getWidth(context) / 2,
                objectFit: BoxFit.fill,
              ),
            ),
          ],
        );
        i++; // Skip the next ad as it has been processed
      } else if (ads[i]['chosenOption'] == '1 x 1') {
        // Handle a single '1 x 1' ad when no pair is available
        adWidget = Row(
          children: [
            Expanded(
              child: AsyncImageView(
                radius: 10,
                imagePath: ads[i]['imagePath'],
                width: getWidth(context) / 2,
                height: getWidth(context) / 2,
                objectFit: BoxFit.fill,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ImageView(
                radius: 10,
                imagePath: 'assets/ad1.png',
                width: getWidth(context) / 2,
                height: getWidth(context) / 2,
                objectFit: BoxFit.fill,
              ),
            ),
          ],
        );
      } else {
        // Fallback to an empty Container if no condition matches
        adWidget = Container(); // Ensure adWidget is initialized
      }

      // Wrap the ad widget with VisibilityDetector
      widgets.add(
        VisibilityDetector(
          key: Key('ad_${ads[i]['id']}'), // Use a unique key for each ad
          onVisibilityChanged: (info) {
            if (info.visibleFraction == 1) {
              // Check if fully visible
              if (!_seenAdIds.contains(ads[i]['id'])) {
                onAdView(ads[i]['id']);
              }
            }
          },
          child: PaddingView(
            paddingTop: 5,
            paddingBottom: 5,
            paddingLeft: 10,
            paddingRight: 10,
            child: ButtonView(
              radius: 10,
              onPress: () async {
                final success = await firebase_CreateDocument(
                    '${appName}_Clicks',
                    randomString(25),
                    {'userId': widget.dm.user['id'], 'adId': ads[i]['id']});
                if (success) {
                  nav_Push(
                    context,
                    UserBusinessProfile(dm: widget.dm, ad: ads[i]),
                    () => setState(() {}),
                  );
                }
              },
              child: adWidget,
            ),
          ),
        ),
      );
    }
    if (ads.length == 0) {
      widgets.add(Center(
        child: PaddingView(
          paddingTop: 20,
          paddingBottom: 20,
          paddingLeft: 20,
          paddingRight: 20,
          child: TextView(
            text: 'Change your filters to expand and see what else is around.',
            size: 18,
          ),
        ),
      ));
    }
    return widgets;
  }

  void onAdView(String adId) async {
    setState(() {
      _seenAdIds.add(adId);
    });
    await firebase_CreateDocument('${appName}_Views', randomString(25),
        {'userId': widget.dm.user['id'], 'adId': adId});
    print('the ad ${adId} was seen');
  }

  void init() async {
    if (widget.dm.user['geohash'] == null) {
      final loc = await getLocation(context);
      if (loc != null) {
        final geohash = Geohash.encode(loc.latitude, loc.longitude);
        final succ = await firebase_UpdateDocument(
            '${appName}_Users', widget.dm.user['id'], {'geohash': geohash});
        if (succ) {
          setState(() {
            widget.dm.setMyLocation(LatLng(loc.latitude, loc.longitude));
            widget.dm.setUser({...widget.dm.user, 'geohash': geohash});
          });
        }
      }
    } else {
      final coords = Geohash.decode(widget.dm.user['geohash']);
      setState(() {
        widget.dm
            .setMyLocation(LatLng(coords['latitude']!, coords['longitude']!));
      });
    }
  }

  @override
  void initState() {
    super.initState();

    init();
    _fetchLocalAds(); // Fetch ads on initialization
  }

  @override
  Widget build(BuildContext context) {
    return MainView(
      dm: widget.dm,
      children: [
        PaddingView(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  ImageView(
                    imagePath: 'assets/logo.png',
                    width: 30,
                    height: 30,
                    radius: 6,
                  ),
                  SizedBox(width: 6),
                  TextView(
                    text: 'Explore',
                    size: 18,
                    weight: FontWeight.w500,
                    wrap: false,
                  ),
                ],
              ),
              Row(
                children: [
                  ButtonView(
                    child: Icon(
                      Icons.tune_outlined,
                      size: 34,
                      color: hexToColor('#353841'),
                    ),
                    onPress: () {
                      nav_Push(context, Filters(dm: widget.dm), () {
                        lastDoc = null;
                        _fetchLocalAds();
                      });
                    },
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  ButtonView(
                    child: Icon(
                      Icons.face,
                      color: hexToColor("#3490F3"),
                      size: 34,
                    ),
                    onPress: () {
                      nav_Push(context, Profile(dm: widget.dm), () {
                        setState(() {});
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        //
        if (widget.dm.myLocation != null)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Column(
                    children: buildAdWidgets(context, ads),
                  ),
                  if (_noMore)
                    ImageView(
                      imagePath: 'assets/nomore.png',
                      width: getWidth(context) * 0.8,
                      height: getWidth(context) * 0.6,
                      objectFit: BoxFit.contain,
                    ),
                  if (!_noMore)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PaddingView(
                          child: ButtonView(
                              child: Row(
                                children: [
                                  TextView(
                                    text: 'see more',
                                    size: 20,
                                    weight: FontWeight.w500,
                                    spacing: -1,
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  Icon(
                                    Icons.waving_hand_outlined,
                                    size: 24,
                                    color: hexToColor("#3490F3"),
                                  )
                                ],
                              ),
                              onPress: () {
                                _fetchLocalAds();
                              }),
                        ),
                      ],
                    )
                ],
              ),
            ),
          )
        else
          PaddingView(
            paddingLeft: 20,
            paddingRight: 20,
            child: Column(
              children: [
                TextView(
                  text:
                      'Enable your location or set a location in your filters to view ads.',
                  size: 16,
                  wrap: true,
                  isTypewriter: true,
                ),
                SizedBox(
                  height: 15,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ButtonView(
                        paddingTop: 8,
                        paddingBottom: 8,
                        paddingLeft: 18,
                        paddingRight: 18,
                        radius: 100,
                        backgroundColor: hexToColor('#3490F3'),
                        child: Row(
                          children: [
                            TextView(
                              text: 'Get Location',
                              size: 16,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            Icon(Icons.location_on,
                                size: 26, color: Colors.white)
                          ],
                        ),
                        onPress: () async {
                          final loc = await getLocation(context);
                          if (loc != null) {
                            final geohash =
                                Geohash.encode(loc.latitude, loc.longitude);
                            final succ = await firebase_CreateDocument(
                                '${geohash}_Users',
                                widget.dm.user['id'],
                                {'geohash': geohash});
                            if (succ) {
                              setState(() {
                                widget.dm.setMyLocation(
                                    LatLng(loc.latitude, loc.longitude));
                              });
                            }
                          }
                        }),
                  ],
                )
              ],
            ),
          )
      ],
    );
  }
}
