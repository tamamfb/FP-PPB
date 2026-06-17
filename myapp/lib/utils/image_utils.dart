import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

ImageProvider? photoImageProvider(String? photoURL) {
  if (photoURL == null || photoURL.isEmpty) return null;
  if (photoURL.startsWith('http')) return CachedNetworkImageProvider(photoURL);
  return MemoryImage(base64Decode(photoURL));
}
