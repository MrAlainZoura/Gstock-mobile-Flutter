import 'package:flutter/material.dart';
import 'show.dart';
import '../../models/depot.dart';

class DepotListPage extends StatelessWidget {
  final List<Depot> depots;

  const DepotListPage({Key? key, required this.depots}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Liste des dépôts")),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // nombre de colonnes
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: depots.length,
        itemBuilder: (context, index) {
          final depot = depots[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DepotDetailPage(depot: depot),
                ),
              );
            },
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  depot.libele, // suppose que ton modèle a un champ "nom"
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Text Text(
//   String data, {
//   Key? key,
//   TextStyle? style,
//   StrutStyle? strutStyle,
//   TextAlign? textAlign,
//   TextDirection? textDirection,
//   Locale? locale,
//   bool? softWrap,
//   TextOverflow? overflow,
//   double? textScaleFactor,
//   TextScaler? textScaler,
//   int? maxLines,
//   String? semanticsLabel,
//   String? semanticsIdentifier,
//   TextWidthBasis? textWidthBasis,
//   TextHeightBehavior? textHeightBehavior,
//   Color? selectionColor,
// })
// Declared in Text in package:flutter/src/widgets/text.dart.

