/// An etichetta offered by the `PostinoLabelPicker`: its Provider `id` and the `name` shown.
typedef PostinoLabelOption = ({String id, String name});

/// The texts of a PostinoLabelPicker, from the caller's translations.
class const PostinoLabelPickerStrings({
  /// Nome del campo di ricerca: «Cerca o crea un'Etichetta».
  required final String search,

  /// Aiuto sotto il campo: «Usa «/» per annidarla, es. Progetti/Postino.».
  required final String nestHelp,

  /// La riga che crea l'etichetta scritta: «Crea «Viaggi»».
  required final String Function(String name) create,

  /// Annuncio e intestazione: «Etichette, 2 selezionate».
  required final String Function(int count) selected,

  /// Quando nessuna etichetta corrisponde e non c'è niente da creare: «Nessuna Etichetta».
  required final String empty,
}) {
  /// Crea i testi del selettore.
  this;
}
