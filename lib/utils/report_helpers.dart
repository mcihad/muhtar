import 'package:intl/intl.dart';

/// Rapor üst bilgisi oluşturur
String buildReportHeader({
  required String reportTitle,
  required String muhtarAdi,
  String? muhtarTel,
  String? antetBaslik,
  String? antetAdres,
}) {
  final now = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

  final header = StringBuffer();
  header.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  if (antetBaslik != null && antetBaslik.isNotEmpty) {
    header.writeln(antetBaslik);
  }
  if (antetAdres != null && antetAdres.isNotEmpty) {
    header.writeln(antetAdres);
  }
  header.writeln('Muhtar: $muhtarAdi');
  if (muhtarTel != null && muhtarTel.isNotEmpty) {
    header.writeln('Tel: $muhtarTel');
  }
  header.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  header.writeln('');
  header.writeln(reportTitle);
  header.writeln('Rapor Tarihi: $now');
  header.writeln('');

  return header.toString();
}

/// Rapor alt bilgisi oluşturur
String buildReportFooter({String? altBilgi, bool includeDeveloperInfo = true}) {
  final footer = StringBuffer();
  footer.writeln('');
  footer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  if (altBilgi != null && altBilgi.isNotEmpty) {
    footer.writeln(altBilgi);
    footer.writeln('');
  }

  if (includeDeveloperInfo) {
    footer.writeln('Sivas Belediyesi');
    footer.writeln('Akıllı Şehir ve Kent Bilgi Sistemleri Müdürlüğü');
    footer.writeln('tarafından geliştirilmiştir.');
  }

  footer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  return footer.toString();
}
