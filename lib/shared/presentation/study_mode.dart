/// Visible study phase; independent of book/cycle scoring and navigation.
enum StudyMode {
  reading('Reading'),
  solving('Solving'),
  review('Review');

  const StudyMode(this.label);

  final String label;
}
