import 'package:comprehensive_exam_system/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the exam home page', (tester) async {
    await tester.pumpWidget(const ExamApp());
    await tester.pump();

    expect(find.text('考试练习系统'), findsWidgets);
    expect(find.text('练习'), findsWidgets);
  });
}
