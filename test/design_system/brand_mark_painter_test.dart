import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/atoms/postino_brand_mark_painter.dart';
import 'package:postino/design_system/tokens/postino_palette.dart';

void main() {
  PostinoBrandMarkPainter at(int ms) => PostinoBrandMarkPainter(AlwaysStoppedAnimation(ms / 900));

  test('at 0 ms the envelope is closed, the letter inside', () {
    expect(at(0).flapFold, -1);
    expect(at(0).letterRise, 0);
  });

  test('at 250 ms the flap is open, the letter still inside', () {
    expect(at(250).flapFold, closeTo(1, 1e-9));
    expect(at(250).letterRise, 0);
  });

  test('halfway the flap is open and the letter on its way out', () {
    expect(at(450).flapFold, 1);
    expect(at(450).letterRise, inExclusiveRange(0, 1));
  });

  test('at 900 ms the pose is mark.svg', () {
    expect(at(900).flapFold, 1);
    expect(at(900).letterRise, 1);
  });

  // The painter draws with these tokens; the SVGs must use the same values (#293).
  String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  final pocket = 'Q40 204 40 190 Z" fill="${hex(PostinoPrimitives.pNeutral300)}"';
  final flap = 'fill="${hex(PostinoPrimitives.pNeutral400)}"';

  test('mark.svg uses the painter colors', () {
    final svg = File('assets/brand/mark.svg').readAsStringSync();
    expect(svg, contains(pocket));
    expect(svg, contains('L128 56 L216 128 Z" $flap'));
    expect(svg, contains('rx="10" fill="${hex(PostinoPrimitives.pNeutral0)}"'));
    expect(svg, contains('stroke="${hex(PostinoPrimitives.pGold400)}"'));
  });

  test('mark-closed.svg is the painter at 0 ms', () {
    final svg = File('assets/brand/mark-closed.svg').readAsStringSync();
    expect(svg, contains(pocket));
    expect(svg, contains('L128 200 L216 128 Z" $flap'));
  });
}
