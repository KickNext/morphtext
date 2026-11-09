// Records: MorphText inside a real Hero flight.
//
// A small record library. Tap an album and its sleeve and title fly to the
// album page, where the record slides out of its sleeve and spins; back tucks
// it away and flies everything home.
//
// The title's Hero hands its flight to MorphText through flightShuttleBuilder:
// Red Hat Display Black 15 with open letter spacing in the list, Fraunces
// SemiBold 30 with tight spacing on the page, so font, weight, size and
// spacing morph in one go. The flight's animation is the album page's route
// animation, 0 in the list and 1 on the page in both directions, so `from` and
// `to` never swap. Two things make a Hero flight look right:
//
// - Wrap the shuttle in a transparent Material. The flight happens in the
//   navigator's overlay, outside the page's Scaffold, and the plain text
//   MorphText draws at either end of the flight would otherwise get Flutter's
//   yellow "no Material" underline.
// - Give square artwork a straight RectTween. Material's default flight arcs
//   the corners, which bends a square out of shape on the way.
//
//   flutter run -t lib/records_main.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:morphtext/morphtext.dart';

const ink = Color(0xff111214);
const paper = Color(0xfff3efe7);
const quiet = Color(0xff8a8d93);
const phoneBg = Color(0xff1b1c20);

/// The faces the records use, and the styles built from them. The app uses
/// the bundled families; anything else (a test bundle, say) can pass its own.
class RecordFonts extends InheritedWidget {
  const RecordFonts({
    super.key,
    this.serif = const TextStyle(fontFamily: 'Fraunces'),
    this.sansFace = const TextStyle(fontFamily: 'RedHatDisplay'),
    required super.child,
  });

  /// Fraunces: Light (300) and SemiBold (600).
  final TextStyle serif;

  /// Red Hat Display: Light (300) and Black (900).
  final TextStyle sansFace;

  TextStyle get light => serif.copyWith(fontWeight: FontWeight.w300);
  TextStyle get bold => serif.copyWith(fontWeight: FontWeight.w600);
  TextStyle get sans => sansFace.copyWith(fontWeight: FontWeight.w900);

  /// The list's title: heavy, small, open.
  TextStyle get listTitle =>
      sans.copyWith(fontSize: 15, letterSpacing: .8, color: paper);

  /// The page's title: a serif, big, tight.
  TextStyle get pageTitle => bold.copyWith(
    fontSize: 30,
    letterSpacing: -.6,
    color: paper,
    height: 1.1,
  );

  TextStyle get listArtist => sansFace.copyWith(
    fontWeight: FontWeight.w300,
    fontSize: 12,
    color: quiet,
  );

  TextStyle get pageArtist =>
      light.copyWith(fontSize: 17, color: const Color(0xffc9c4ba));

  static RecordFonts of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RecordFonts>() ??
      const RecordFonts(child: SizedBox());

  @override
  bool updateShouldNotify(RecordFonts old) =>
      old.serif != serif || old.sansFace != sansFace;
}

/// The records as an app.
class RecordsApp extends StatelessWidget {
  const RecordsApp({super.key, this.fonts});

  /// The faces to use; the bundled Fraunces and Red Hat Display when null.
  final RecordFonts Function(Widget child)? fonts;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Records',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    builder: (context, child) =>
        fonts?.call(child!) ?? RecordFonts(child: child!),
    home: const Library(),
  );
}

typedef Album = ({
  String id,
  String title,
  String artist,
  String meta,
  List<String> tracks,
  List<Color> art,
  Color label,
});

const albums = <Album>[
  (
    id: 'tide',
    title: 'Neon Tide',
    artist: 'The Late Hours',
    meta: 'LP  ·  1987  ·  9 tracks',
    tracks: <String>[],
    art: [Color(0xffff6b6b), Color(0xff6c3bd1)],
    label: Color(0xffffd23f),
  ),
  (
    id: 'moons',
    title: 'Paper Moons',
    artist: 'Quiet Machines',
    meta: 'LP  ·  1994  ·  11 tracks',
    tracks: ['Folded Light', 'Origami Sky', 'Crease', 'Low Tide Radio'],
    art: [Color(0xff2bb5a3), Color(0xff1d3557)],
    label: Color(0xfff3efe7),
  ),
  (
    id: 'static',
    title: 'Midnight Static',
    artist: 'Velvet Signal',
    meta: 'EP  ·  2003  ·  5 tracks',
    tracks: <String>[],
    art: [Color(0xffffb347), Color(0xffd7263d)],
    label: Color(0xff111214),
  ),
];

// ---- The sleeve and the record ----

class Sleeve extends StatelessWidget {
  const Sleeve(this.album, {super.key});
  final Album album;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SleevePainter(album));
}

class _SleevePainter extends CustomPainter {
  _SleevePainter(this.album);
  final Album album;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final round = RRect.fromRectAndRadius(r, Radius.circular(size.width * .03));
    canvas.save();
    canvas.clipRRect(round);
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: album.art,
        ).createShader(r),
    );
    // A sun and its rings: every sleeve the same idea, its own colours.
    final c = Offset(size.width * .62, size.height * .42);
    for (var k = 5; k >= 1; k--) {
      canvas.drawCircle(
        c,
        size.width * .09 * k,
        Paint()
          ..color = Colors.white.withValues(alpha: .06 + .02 * (5 - k))
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .012,
      );
    }
    canvas.drawCircle(c, size.width * .14, Paint()..color = album.label);
    // A horizon.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .74, size.width, size.height * .26),
      Paint()..color = Colors.black.withValues(alpha: .28),
    );
    canvas.restore();
    canvas.drawRRect(
      round,
      Paint()
        ..color = Colors.white.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SleevePainter old) => old.album != album;
}

class Record extends StatelessWidget {
  const Record(this.album, {super.key, required this.turn});
  final Album album;
  final double turn;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: turn * 2 * math.pi,
    child: CustomPaint(painter: _RecordPainter(album)),
  );
}

class _RecordPainter extends CustomPainter {
  _RecordPainter(this.album);
  final Album album;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xff0b0b0c));
    // Grooves.
    for (var k = 0; k < 18; k++) {
      canvas.drawCircle(
        c,
        r * (.42 + .52 * k / 18),
        Paint()
          ..color = Colors.white.withValues(alpha: k.isEven ? .05 : .025)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
    }
    // A sheen, so the spin shows.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .13),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .1),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, .08, .18, .5, .58, .68],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // The label, with a mark off centre so the turn reads.
    canvas.drawCircle(c, r * .34, Paint()..color = album.label);
    canvas.drawCircle(
      c + Offset(0, -r * .2),
      r * .05,
      Paint()..color = album.art.last,
    );
    canvas.drawCircle(c, r * .035, Paint()..color = const Color(0xff0b0b0c));
  }

  @override
  bool shouldRepaint(_RecordPainter old) => old.album != album;
}

// ---- The two screens ----

/// A straight flight. Material's default arcs the corners, which bends a
/// square sleeve out of shape on the way.
RectTween straight(Rect? begin, Rect? end) => RectTween(begin: begin, end: end);

/// The sleeve in the air: lifted off the shelf with a tilt, a little scale
/// and a shadow that peak mid-flight and settle as it lands.
Widget liftedSleeve(Album album, Animation<double> animation) =>
    AnimatedBuilder(
      animation: animation,
      child: Sleeve(album),
      builder: (context, child) {
        final air = math.sin(math.pi * animation.value.clamp(0.0, 1.0));
        final scale = 1 + .14 * air;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0015)
            ..rotateY(-.42 * air)
            ..rotateZ(-.07 * air)
            ..multiply(Matrix4.diagonal3Values(scale, scale, 1)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .6 * air),
                  blurRadius: 44 * air,
                  offset: Offset(0, 26 * air),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );

/// A line of text that flies between the list and the page. Its Hero hands
/// the flight to MorphText, from the list's style to the page's: the flight's
/// animation is the page route's, so it runs 0 to 1 opening and 1 to 0
/// closing, and `from` and `to` stay put.
Widget heroText(
  String tag,
  String text, {
  required TextStyle list,
  required TextStyle page,
  required bool onPage,
}) => Hero(
  tag: tag,
  createRectTween: straight,
  flightShuttleBuilder: (context, animation, direction, from, to) =>
      OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        // The flight happens in the navigator's overlay, outside the page's
        // Scaffold: without a Material, the plain text MorphText draws at
        // either end gets Flutter's yellow "no Material" underline.
        child: Material(
          type: MaterialType.transparency,
          child: MorphText(text, from: list, to: page, progress: animation),
        ),
      ),
  child: Text(text, style: onPage ? page : list, maxLines: 1, softWrap: false),
);

class Library extends StatelessWidget {
  const Library({super.key});

  @override
  Widget build(BuildContext context) {
    final f = RecordFonts.of(context);
    return Scaffold(
      backgroundColor: phoneBg,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(22, 34, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Records', style: f.bold.copyWith(fontSize: 28, color: paper)),
            const SizedBox(height: 4),
            Text(
              '3 in the crate',
              style: f.light.copyWith(fontSize: 13, color: quiet),
            ),
            const SizedBox(height: 22),
            for (var k = 0; k < albums.length; k++) _row(context, k),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int k) {
    final f = RecordFonts.of(context);
    final album = albums[k];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white.withValues(alpha: .08),
        // A plain ripple: Material 3's sparkle reads as noise in a video.
        splashFactory: InkRipple.splashFactory,
        // No pressed band, and a ripple that stays a small circle on the
        // sleeve: a row-wide band's edge reads as an underline mid-flight.
        highlightColor: Colors.transparent,
        radius: 38,
        onTap: () => Navigator.of(context).push(albumRoute(album)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(
            children: [
              SizedBox.square(
                key: ValueKey('sleeve-${album.id}'),
                dimension: 62,
                child: Hero(
                  tag: 'sleeve-${album.id}',
                  createRectTween: straight,
                  flightShuttleBuilder: (context, animation, _, _, _) =>
                      liftedSleeve(album, animation),
                  child: Sleeve(album),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heroText(
                    'title-${album.id}',
                    album.title,
                    list: f.listTitle,
                    page: f.pageTitle,
                    onPage: false,
                  ),
                  const SizedBox(height: 4),
                  heroText(
                    'artist-${album.id}',
                    album.artist,
                    list: f.listArtist,
                    page: f.pageArtist,
                    onPage: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The album page. The list stays underneath (not opaque) and dims away in the
/// first part of the flight; the page's own content fades in only in the last
/// part, so the flying sleeve and title carry the move.
Route<void> albumRoute(Album album) => PageRouteBuilder(
  opaque: false,
  transitionDuration: const Duration(milliseconds: 900),
  reverseTransitionDuration: const Duration(milliseconds: 800),
  pageBuilder: (context, animation, secondary) => AlbumPage(album),
  transitionsBuilder: (context, animation, secondary, child) => Stack(
    children: [
      Positioned.fill(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0, .45, curve: Curves.easeOut),
          ),
          child: const ColoredBox(color: phoneBg),
        ),
      ),
      Positioned.fill(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(.55, 1, curve: Curves.easeOut),
          ),
          child: child,
        ),
      ),
    ],
  ),
);

class AlbumPage extends StatefulWidget {
  const AlbumPage(this.album, {super.key});
  final Album album;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> with TickerProviderStateMixin {
  // The record sliding out of its sleeve, and its spin.
  late final out = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  Animation<double>? route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    route ??= ModalRoute.of(context)!.animation!
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && out.isDismissed) {
          out.forward();
          spin.repeat();
        }
      });
  }

  /// Tucks the record away, then goes back.
  Future<void> close() async {
    await out.reverse();
    spin.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    out.dispose();
    spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = RecordFonts.of(context);
    final album = widget.album;
    const sleeve = 196.0;
    return Scaffold(
      backgroundColor: phoneBg,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 26, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              key: const ValueKey('back'),
              onPressed: close,
              icon: const Icon(Icons.arrow_back, color: paper),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 290,
                height: sleeve,
                child: AnimatedBuilder(
                  animation: Listenable.merge([out, spin]),
                  builder: (context, _) {
                    final slide = Curves.easeOutBack.transform(out.value);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (out.value > 0)
                          Positioned(
                            left: 6 + 82 * slide,
                            top: 6,
                            width: sleeve - 12,
                            height: sleeve - 12,
                            child: Record(album, turn: spin.value),
                          ),
                        Positioned(
                          left: 0,
                          top: 0,
                          width: sleeve,
                          height: sleeve,
                          child: Hero(
                            tag: 'sleeve-${album.id}',
                            createRectTween: straight,
                            flightShuttleBuilder:
                                (context, animation, _, _, _) =>
                                    liftedSleeve(album, animation),
                            child: Sleeve(album),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heroText(
                    'title-${album.id}',
                    album.title,
                    list: f.listTitle,
                    page: f.pageTitle,
                    onPage: true,
                  ),
                  const SizedBox(height: 6),
                  heroText(
                    'artist-${album.id}',
                    album.artist,
                    list: f.listArtist,
                    page: f.pageArtist,
                    onPage: true,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    album.meta,
                    style: f.light.copyWith(fontSize: 12, color: quiet),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: paper,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: ink, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Play',
                          style: f.sans.copyWith(fontSize: 13, color: ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (var k = 0; k < album.tracks.length; k++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${k + 1}',
                              style: f.light.copyWith(
                                fontSize: 12,
                                color: quiet,
                              ),
                            ),
                          ),
                          Text(
                            album.tracks[k],
                            style: f.light.copyWith(
                              fontSize: 14,
                              color: const Color(0xffc9c4ba),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
