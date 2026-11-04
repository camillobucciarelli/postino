// Parte dei token di postino_tokens.dart: vedi lì la fonte da cui sono copiati.
import 'package:flutter/material.dart';

/// Livello 1 — primitivi. Non usarli nei widget: passa da PostinoColors.
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract final class PostinoPrimitives() {
  /// Primitivo neutro caldo, gradino 0.
  static const pNeutral0 = Color(0xFFFFFFFF);

  /// Primitivo neutro caldo, gradino 50.
  static const pNeutral50 = Color(0xFFFBFAF7);

  /// Primitivo neutro caldo, gradino 100.
  static const pNeutral100 = Color(0xFFF4F2EC);

  /// Primitivo neutro caldo, gradino 150.
  static const pNeutral150 = Color(0xFFECE9E1);

  /// Primitivo neutro caldo, gradino 200.
  static const pNeutral200 = Color(0xFFE2DED4);

  /// Primitivo neutro caldo, gradino 300.
  static const pNeutral300 = Color(0xFFCDC8BB);

  /// Primitivo neutro caldo, gradino 400.
  static const pNeutral400 = Color(0xFFA6A093);

  /// Primitivo neutro caldo, gradino 500.
  static const pNeutral500 = Color(0xFF7F7A6E);

  /// Primitivo neutro caldo, gradino 600.
  static const pNeutral600 = Color(0xFF625E55);

  /// Primitivo neutro caldo, gradino 700.
  static const pNeutral700 = Color(0xFF4A4740);

  /// Primitivo neutro caldo, gradino 750.
  static const pNeutral750 = Color(0xFF3A3833);

  /// Primitivo neutro caldo, gradino 800.
  static const pNeutral800 = Color(0xFF2D2C29);

  /// Primitivo neutro caldo, gradino 850.
  static const pNeutral850 = Color(0xFF242422);

  /// Primitivo neutro caldo, gradino 900.
  static const pNeutral900 = Color(0xFF1C1C1A);

  /// Primitivo neutro caldo, gradino 950.
  static const pNeutral950 = Color(0xFF131312);

  /// Primitivo verdigris (colore del brand), gradino 50.
  static const pVerdigris50 = Color(0xFFEBF6F2);

  /// Primitivo verdigris (colore del brand), gradino 100.
  static const pVerdigris100 = Color(0xFFD6EDE5);

  /// Primitivo verdigris (colore del brand), gradino 200.
  static const pVerdigris200 = Color(0xFFA9D9CB);

  /// Primitivo verdigris (colore del brand), gradino 300.
  static const pVerdigris300 = Color(0xFF79C9B3);

  /// Primitivo verdigris (colore del brand), gradino 400.
  static const pVerdigris400 = Color(0xFF4FAE96);

  /// Primitivo verdigris (colore del brand), gradino 500.
  static const pVerdigris500 = Color(0xFF2A917A);

  /// Primitivo verdigris (colore del brand), gradino 600.
  static const pVerdigris600 = Color(0xFF167A66);

  /// Primitivo verdigris (colore del brand), gradino 700.
  static const pVerdigris700 = Color(0xFF0F6B5C);

  /// Primitivo verdigris (colore del brand), gradino 800.
  static const pVerdigris800 = Color(0xFF0B5649);

  /// Primitivo verdigris (colore del brand), gradino 900.
  static const pVerdigris900 = Color(0xFF143A33);

  /// Primitivo verdigris (colore del brand), gradino 950.
  static const pVerdigris950 = Color(0xFF0B231E);

  /// Primitivo rosso, gradino 100.
  static const pRed100 = Color(0xFFFDE8E4);

  /// Primitivo rosso, gradino 300.
  static const pRed300 = Color(0xFFFF9384);

  /// Primitivo rosso, gradino 700.
  static const pRed700 = Color(0xFFB42318);

  /// Primitivo rosso, gradino 900.
  static const pRed900 = Color(0xFF40140F);

  /// Primitivo verde, gradino 100.
  static const pGreen100 = Color(0xFFE2F3E6);

  /// Primitivo verde, gradino 300.
  static const pGreen300 = Color(0xFF74D293);

  /// Primitivo verde, gradino 700.
  static const pGreen700 = Color(0xFF1E6B3A);

  /// Primitivo verde, gradino 900.
  static const pGreen900 = Color(0xFF12301D);

  /// Primitivo ambra, gradino 100.
  static const pAmber100 = Color(0xFFFBEFD4);

  /// Primitivo ambra, gradino 300.
  static const pAmber300 = Color(0xFFEBB84E);

  /// Primitivo ambra, gradino 700.
  static const pAmber700 = Color(0xFF855700);

  /// Primitivo ambra, gradino 900.
  static const pAmber900 = Color(0xFF3A2A08);

  /// Primitivo arancio, gradino 100.
  static const pOrange100 = Color(0xFFFDE9DA);

  /// Primitivo arancio, gradino 300.
  static const pOrange300 = Color(0xFFF2A65E);

  /// Primitivo arancio, gradino 700.
  static const pOrange700 = Color(0xFFB0500A);

  /// Primitivo arancio, gradino 900.
  static const pOrange900 = Color(0xFF3D220C);

  /// Primitivo oro, gradino 300.
  static const pGold300 = Color(0xFFFFE02E);

  /// Primitivo oro, gradino 400.
  static const pGold400 = Color(0xFFF0C419);

  /// Primitivo oro, gradino 700.
  static const pGold700 = Color(0xFF9C5900);

  /// Primitivo azzurro, gradino 100.
  static const pSky100 = Color(0xFFDAF4FD);

  /// Primitivo azzurro, gradino 300.
  static const pSky300 = Color(0xFF5CD5FC);

  /// Primitivo azzurro, gradino 600.
  static const pSky600 = Color(0xFF00779E);

  /// Primitivo azzurro, gradino 900.
  static const pSky900 = Color(0xFF003443);

  /// Primitivo blu, gradino 100.
  static const pBlue100 = Color(0xFFE5EFFF);

  /// Primitivo blu, gradino 300.
  static const pBlue300 = Color(0xFF84A8FD);

  /// Primitivo blu, gradino 600.
  static const pBlue600 = Color(0xFF3559C3);

  /// Primitivo blu, gradino 900.
  static const pBlue900 = Color(0xFF1F2C4C);

  /// Primitivo viola, gradino 100.
  static const pViolet100 = Color(0xFFF0EBFF);

  /// Primitivo viola, gradino 300.
  static const pViolet300 = Color(0xFFC8ABFF);

  /// Primitivo viola, gradino 600.
  static const pViolet600 = Color(0xFF6C3FAF);

  /// Primitivo viola, gradino 900.
  static const pViolet900 = Color(0xFF322748);

  /// Primitivo magenta, gradino 100.
  static const pMagenta100 = Color(0xFFFBE8F8);

  /// Primitivo magenta, gradino 300.
  static const pMagenta300 = Color(0xFFD782CB);

  /// Primitivo magenta, gradino 600.
  static const pMagenta600 = Color(0xFF95388B);

  /// Primitivo magenta, gradino 900.
  static const pMagenta900 = Color(0xFF3F223B);

  /// Primitivo rosa, gradino 100.
  static const pRose100 = Color(0xFFFFE7ED);

  /// Primitivo rosa, gradino 300.
  static const pRose300 = Color(0xFFFFA9C7);

  /// Primitivo rosa, gradino 600.
  static const pRose600 = Color(0xFFB43C6B);

  /// Primitivo rosa, gradino 900.
  static const pRose900 = Color(0xFF46202D);

  /// Primitivo oliva, gradino 100.
  static const pOlive100 = Color(0xFFEEF1DA);

  /// Primitivo oliva, gradino 300.
  static const pOlive300 = Color(0xFFD3D979);

  /// Primitivo oliva, gradino 600.
  static const pOlive600 = Color(0xFF6B6F00);

  /// Primitivo oliva, gradino 900.
  static const pOlive900 = Color(0xFF2F3106);

  /// Primitivo ardesia, gradino 100.
  static const pSlate100 = Color(0xFFE9EFF6);

  /// Primitivo ardesia, gradino 300.
  static const pSlate300 = Color(0xFF95A7BA);

  /// Primitivo ardesia, gradino 600.
  static const pSlate600 = Color(0xFF445465);

  /// Primitivo ardesia, gradino 900.
  static const pSlate900 = Color(0xFF262F38);

  /// Primitivo grafite, gradino 100.
  static const pGraphite100 = Color(0xFFF3EEE6);

  /// Primitivo grafite, gradino 300.
  static const pGraphite300 = Color(0xFFE2DDD5);

  /// Primitivo grafite, gradino 600.
  static const pGraphite600 = Color(0xFF403D36);

  /// Primitivo grafite, gradino 900.
  static const pGraphite900 = Color(0xFF332D23);

  /// Etichetta Stone: sfondo, tema chiaro.
  static const pLabelStoneBgLight = Color(0xFFEBE8E1);

  /// Etichetta Stone: testo, tema chiaro.
  static const pLabelStoneFgLight = Color(0xFF4A4740);

  /// Etichetta Stone: sfondo, tema scuro.
  static const pLabelStoneBgDark = Color(0xFF34332F);

  /// Etichetta Stone: testo, tema scuro.
  static const pLabelStoneFgDark = Color(0xFFD6D2C8);

  /// Etichetta Sand: sfondo, tema chiaro.
  static const pLabelSandBgLight = Color(0xFFF5EAD2);

  /// Etichetta Sand: testo, tema chiaro.
  static const pLabelSandFgLight = Color(0xFF6B4D10);

  /// Etichetta Sand: sfondo, tema scuro.
  static const pLabelSandBgDark = Color(0xFF3B3222);

  /// Etichetta Sand: testo, tema scuro.
  static const pLabelSandFgDark = Color(0xFFE8CF9A);

  /// Etichetta Sage: sfondo, tema chiaro.
  static const pLabelSageBgLight = Color(0xFFE1ECDF);

  /// Etichetta Sage: testo, tema chiaro.
  static const pLabelSageFgLight = Color(0xFF355230);

  /// Etichetta Sage: sfondo, tema scuro.
  static const pLabelSageBgDark = Color(0xFF26332A);

  /// Etichetta Sage: testo, tema scuro.
  static const pLabelSageFgDark = Color(0xFFB9D4B3);

  /// Etichetta Sea: sfondo, tema chiaro.
  static const pLabelSeaBgLight = Color(0xFFDCECF0);

  /// Etichetta Sea: testo, tema chiaro.
  static const pLabelSeaFgLight = Color(0xFF1F4F5C);

  /// Etichetta Sea: sfondo, tema scuro.
  static const pLabelSeaBgDark = Color(0xFF1D3238);

  /// Etichetta Sea: testo, tema scuro.
  static const pLabelSeaFgDark = Color(0xFFA9D3DE);

  /// Etichetta Lilac: sfondo, tema chiaro.
  static const pLabelLilacBgLight = Color(0xFFECE5F3);

  /// Etichetta Lilac: testo, tema chiaro.
  static const pLabelLilacFgLight = Color(0xFF553F70);

  /// Etichetta Lilac: sfondo, tema scuro.
  static const pLabelLilacBgDark = Color(0xFF302A3B);

  /// Etichetta Lilac: testo, tema scuro.
  static const pLabelLilacFgDark = Color(0xFFD2C3E6);

  /// Etichetta Blush: sfondo, tema chiaro.
  static const pLabelBlushBgLight = Color(0xFFF6E3E1);

  /// Etichetta Blush: testo, tema chiaro.
  static const pLabelBlushFgLight = Color(0xFF77352D);

  /// Etichetta Blush: sfondo, tema scuro.
  static const pLabelBlushBgDark = Color(0xFF3D2826);

  /// Etichetta Blush: testo, tema scuro.
  static const pLabelBlushFgDark = Color(0xFFECBDB6);
}
