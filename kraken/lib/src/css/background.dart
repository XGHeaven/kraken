/*
 * Copyright (C) 2019-present Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:kraken/painting.dart';
import 'package:kraken/rendering.dart';
import 'package:kraken/css.dart';

// CSS Backgrounds: https://drafts.csswg.org/css-backgrounds/
// CSS Images: https://drafts.csswg.org/css-images-3/

/// The [CSSBackgroundMixin] mixin used to handle background shorthand and compute
/// to single value of background
/// 

final RegExp _splitRegExp = RegExp(r'\s+');

mixin CSSBackgroundMixin {

  RenderDecorateElementBox _renderDecorateElementBox;

  void updateBackground(CSSStyleDeclaration style, String property, String value, RenderObjectWithChildMixin parent, int targetId) {
    if (!CSSBackground.hasLocalBackgroundImage(style)) return;

    if (style[BACKGROUND_IMAGE].isNotEmpty) {
      DecorationImage decorationImage;
      Gradient gradient;
      List<CSSFunctionalNotation> methods = CSSFunction(style[BACKGROUND_IMAGE]).computedValue;
      // @FIXME: flutter just support one property
      for (CSSFunctionalNotation method in methods) {
        if (method.name == 'url') {
          decorationImage = CSSBackground.getDecorationImage(style, method);
        } else {
          gradient = CSSBackground.getBackgroundGradient(method);
        }

        if (decorationImage != null || gradient != null) {
          _updateRenderGradient(decorationImage, gradient, parent, targetId);
          return;
        }
      }
    }
  }

  void _updateRenderGradient(DecorationImage decorationImage, Gradient gradient, RenderObjectWithChildMixin parent, int targetId) {
    if (_renderDecorateElementBox != null) {
      _renderDecorateElementBox.decoration = BoxDecoration(
        image: decorationImage,
        gradient: gradient
      );
    } else {
      RenderObject child = parent.child;
      parent.child = null;
      _renderDecorateElementBox = RenderDecorateElementBox(
        decoration: BoxDecoration(image: decorationImage, gradient: gradient),
        child: child
      );
      parent.child = _renderDecorateElementBox;
    }
  }
}

class CSSColorStop {
  Color color;
  double stop;
  CSSColorStop(this.color, this.stop);
}

class CSSBackground {
  static bool isValidBackgroundRepeatValue(String value) {
    return value == REPEAT ||
      value == NO_REPEAT ||
      value == REPEAT_X ||
      value == REPEAT_Y;
  }

  static bool isValidBackgroundSizeValue(String value) {
    return value == AUTO ||
        value == CONTAIN ||
        value == COVER ||
        value == FIT_WIDTH ||
        value == FIT_HEIGTH ||
        value == SCALE_DOWN ||
        value == FILL ||
        CSSLength.isLength(value) ||
        CSSPercentage.isPercentage(value);
  }

  static bool isValidBackgroundAttachmentValue(String value) {
    return value == SCROLL || value == LOCAL;
  }

  static bool isValidBackgroundImageValue(String value) {
    return value.startsWith('url(') ||
      value.startsWith('linear-gradient(') ||
      value.startsWith('repeating-linear-gradient(') ||
      value.startsWith('radial-gradient(') ||
      value.startsWith('repeating-radial-gradient(') ||
      value.startsWith('conic-gradient(');
  }

  static bool isValidBackgroundPositionValue(String value) {
    return value == CSSPosition.CENTER ||
      value == CSSPosition.LEFT ||
      value == CSSPosition.RIGHT ||
      value == CSSPosition.TOP ||
      value == CSSPosition.BOTTOM ||
      CSSLength.isLength(value) ||
      CSSPercentage.isPercentage(value);
  }

  static Color getBackgroundColor(CSSStyleDeclaration style) {
    Color backgroundColor;
    if (style[BACKGROUND_COLOR].isNotEmpty) {
      backgroundColor = CSSColor.parseColor(style[BACKGROUND_COLOR]);
    }
    return backgroundColor;
  }

  static bool hasLocalBackgroundImage(CSSStyleDeclaration style) {
    return style[BACKGROUND_IMAGE].isNotEmpty && style[BACKGROUND_ATTACHMENT] == LOCAL;
  }

  static bool hasScrollBackgroundImage(CSSStyleDeclaration style) {
    String attachment = style[BACKGROUND_ATTACHMENT];
    // Default is `scroll` attachment
    return style[BACKGROUND_IMAGE].isNotEmpty && (attachment.isEmpty || attachment == SCROLL);
  }

  static DecorationImage getDecorationImage(CSSStyleDeclaration style, CSSFunctionalNotation method) {
    DecorationImage backgroundImage;

    String url = method.args.length > 0 ? method.args[0] : '';
    if (url == null || url.isEmpty) {
      return null;
    }

    ImageRepeat imageRepeat = ImageRepeat.repeat;
    if (style[BACKGROUND_REPEAT].isNotEmpty) {
      switch (style[BACKGROUND_REPEAT]) {
        case REPEAT_X:
          imageRepeat = ImageRepeat.repeatX;
          break;
        case REPEAT_Y:
          imageRepeat = ImageRepeat.repeatY;
          break;
        case NO_REPEAT:
          imageRepeat = ImageRepeat.noRepeat;
          break;
      }
    }

    BoxFit boxFit = BoxFit.none;
    if (style[BACKGROUND_SIZE].isNotEmpty) {
      switch (style[BACKGROUND_SIZE]) {
        case COVER:
          boxFit = BoxFit.cover;
          break;
        case CONTAIN:
          boxFit = BoxFit.contain;
          break;
        case FILL:
          boxFit = BoxFit.fill;
          break;
        case FIT_WIDTH:
          boxFit = BoxFit.fitWidth;
          break;
        case FIT_HEIGTH:
          boxFit = BoxFit.fitHeight;
          break;
        case SCALE_DOWN:
          boxFit = BoxFit.scaleDown;
          break;
      }
    }

    backgroundImage = DecorationImage(
      image: CSSUrl(url).computedValue,
      repeat: imageRepeat,
      alignment: CSSPosition.parsePosition(style[BACKGROUND_POSITION]),
      fit: boxFit
    );

    return backgroundImage;
  }

  static Gradient getBackgroundGradient(CSSFunctionalNotation method) {
    Gradient gradient;

    if (method.args.length > 1) {
      List<Color> colors = [];
      List<double> stops = [];
      int start = 0;
      switch (method.name) {
        case 'linear-gradient':
        case 'repeating-linear-gradient':
          double linearAngle;
          Alignment begin = Alignment.topCenter;
          Alignment end = Alignment.bottomCenter;
          String arg0 = method.args[0].trim();
          if (arg0.startsWith('to ')) {
            List<String> parts = arg0.split(_splitRegExp);
            if (parts.length >= 2) {
              switch (parts[1]) {
                case LEFT:
                  if (parts.length == 3) {
                    if (parts[2] == TOP) {
                      begin = Alignment.bottomRight;
                      end = Alignment.topLeft;
                    } else if (parts[2] == BOTTOM) {
                      begin = Alignment.topRight;
                      end = Alignment.bottomLeft;
                    }
                  } else {
                    begin = Alignment.centerRight;
                    end = Alignment.centerLeft;
                  }
                  break;
                case TOP:
                  if (parts.length == 3) {
                    if (parts[2] == LEFT) {
                      begin = Alignment.bottomRight;
                      end = Alignment.topLeft;
                    } else if (parts[2] == RIGHT) {
                      begin = Alignment.bottomLeft;
                      end = Alignment.topRight;
                    }
                  } else {
                    begin = Alignment.bottomCenter;
                    end = Alignment.topCenter;
                  }
                  break;
                case RIGHT:
                  if (parts.length == 3) {
                    if (parts[2] == TOP) {
                      begin = Alignment.bottomLeft;
                      end = Alignment.topRight;
                    } else if (parts[2] == BOTTOM) {
                      begin = Alignment.topLeft;
                      end = Alignment.bottomRight;
                    }
                  } else {
                    begin = Alignment.centerLeft;
                    end = Alignment.centerRight;
                  }
                  break;
                case BOTTOM:
                  if (parts.length == 3) {
                    if (parts[2] == LEFT) {
                      begin = Alignment.topRight;
                      end = Alignment.bottomLeft;
                    } else if (parts[2] == RIGHT) {
                      begin = Alignment.topLeft;
                      end = Alignment.bottomRight;
                    }
                  } else {
                    begin = Alignment.topCenter;
                    end = Alignment.bottomCenter;
                  }
                  break;
              }
            }
            linearAngle = null;
            start = 1;
          } else if (CSSAngle.isAngle(arg0)) {
            CSSAngle angle = CSSAngle(arg0);
            linearAngle = angle.angleValue;
            start = 1;
          }
          _applyColorAndStops(start, method.args, colors, stops);
          if (colors.length >= 2) {
            gradient = WebLinearGradient(
                begin: begin,
                end: end,
                angle: linearAngle,
                colors: colors,
                stops: stops,
                tileMode: method.name == 'linear-gradient' ? TileMode.clamp : TileMode.repeated);
          }
          break;
        // @TODO just support circle radial
        case 'radial-gradient':
        case 'repeating-radial-gradient':
          double atX = 0.5;
          double atY = 0.5;
          double radius = 0.5;

          if (method.args[0].contains(PERCENTAGE)) {
            List<String> positionAndRadius = method.args[0].trim().split(' ');
            if (positionAndRadius.length >= 1) {
              if (CSSPercentage.isPercentage(positionAndRadius[0])) {
                radius = CSSPercentage(positionAndRadius[0]).toDouble() * 0.5;
                start = 1;
              }
              if (positionAndRadius.length > 2 && positionAndRadius[1] == 'at') {
                start = 1;
                if (CSSPercentage.isPercentage(positionAndRadius[2])) {
                  atX = CSSPercentage(positionAndRadius[2]).toDouble();
                }
                if (positionAndRadius.length == 4 && CSSPercentage.isPercentage(positionAndRadius[3])) {
                  atY = CSSPercentage(positionAndRadius[3]).toDouble();
                }
              }
            }
          }
          _applyColorAndStops(start, method.args, colors, stops);
          if (colors.length >= 2) {
            gradient = WebRadialGradient(
              center: FractionalOffset(atX, atY),
              radius: radius,
              colors: colors,
              stops: stops,
              tileMode: method.name == 'radial-gradient' ? TileMode.clamp : TileMode.repeated,
            );
          }
          break;
        case 'conic-gradient':
          double from = 0.0;
          double atX = 0.5;
          double atY = 0.5;
          if (method.args[0].contains('from ') || method.args[0].contains('at ')) {
            List<String> fromAt = method.args[0].trim().split(' ');
            int fromIndex = fromAt.indexOf('from');
            int atIndex = fromAt.indexOf('at');
            if (fromIndex != -1 && fromIndex + 1 < fromAt.length) {
              from = CSSAngle(fromAt[fromIndex + 1]).angleValue;
            }
            if (atIndex != -1) {
              if (atIndex + 1 < fromAt.length && CSSPercentage.isPercentage(fromAt[atIndex + 1])) {
                atX = CSSPercentage(fromAt[atIndex + 1]).toDouble();
              }
              if (atIndex + 2 < fromAt.length && CSSPercentage.isPercentage(fromAt[atIndex + 2])) {
                atY = CSSPercentage(fromAt[atIndex + 2]).toDouble();
              }
            }
            start = 1;
          }
          _applyColorAndStops(start, method.args, colors, stops);
          if (colors.length >= 2) {
            gradient = WebConicGradient(
                center: FractionalOffset(atX, atY),
                colors: colors,
                stops: stops,
                transform: GradientRotation(-math.pi / 2 + from));
          }
          break;
      }
    }

    return gradient;
  }


  static void _applyColorAndStops(int start, List<String> args, List<Color> colors, List<double> stops) {
    // colors should more than one, otherwise invalid
    if (args.length - start - 1 > 0) {
      double grow = 1.0 / (args.length - start - 1);
      for (int i = start; i < args.length; i++) {
        List<CSSColorStop> colorGradients = _parseColorAndStop(args[i].trim(), (i - start) * grow);
        colorGradients.forEach((element) {
          colors.add(element.color);
          stops.add(element.stop);
        });
      }
    }
  }

  static List<CSSColorStop> _parseColorAndStop(String src, [double defaultStop]) {
    List<String> strings = [];
    List<CSSColorStop> colorGradients = [];
    // rgba may contain space, color should handle special
    if (src.startsWith('rgba(')) {
      int indexOfRgbaEnd = src.indexOf(')');
      if (indexOfRgbaEnd == -1) {
        // rgba parse error
        return colorGradients;
      }
      strings.add(src.substring(0, indexOfRgbaEnd + 1));
      if (indexOfRgbaEnd + 1 < src.length) {
        strings.addAll(src.substring(indexOfRgbaEnd + 1)?.trim()?.split(' '));
      }
    } else {
      strings = src.split(' ');
    }

    if (strings != null && strings.length >= 1) {
      double stop = defaultStop;
      if (strings.length >= 2) {
        try {
          for (int i = 1; i < strings.length; i++) {
            if (CSSPercentage.isPercentage(strings[i])) {
              stop = CSSPercentage(strings[i]).toDouble();
            } else if (CSSAngle.isAngle(strings[i])) {
              stop = CSSAngle(strings[i]).angleValue / (math.pi * 2);
            }
            colorGradients.add(CSSColorStop(CSSColor.parseColor(strings[0]), stop));
          }
        } catch (e) {}
      } else {
        colorGradients.add(CSSColorStop(CSSColor.parseColor(strings[0]), stop));
      }
    }
    return colorGradients;
  }
}