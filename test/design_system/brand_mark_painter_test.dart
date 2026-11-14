// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/atoms/postino_brand_mark_painter.dart';

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
}
