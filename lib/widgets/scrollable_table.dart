import 'package:flutter/material.dart';

/// Envuelve un [DataTable] con scroll vertical y horizontal.
class ScrollableDataTable extends StatelessWidget {
  const ScrollableDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnSpacing,
    this.headingRowHeight,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double? columnSpacing;
  final double? headingRowHeight;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: columnSpacing ?? 28,
          headingRowHeight: headingRowHeight ?? 52,
          dataRowMinHeight: dataRowMinHeight ?? 52,
          dataRowMaxHeight: dataRowMaxHeight ?? 60,
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }
}
