import 'package:flutter/material.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/value_profile/value_profile_page.dart';

/// Widget that displays dual bars for a single preference
/// Shows both relative weight (blue) and monetary factor (green) side by side
class PreferenceDualBar extends StatefulWidget {
  final PreferenceWeight weight;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final ValueChanged<double> onWeightChange;
  final ValueChanged<double> onMonetaryChange;
  final VoidCallback onLabelTap;
  final bool isSelected;
  final double monetaryScale; // Max monetary value for scaling
  final double percentageScale; // Max percentage value for scaling

  const PreferenceDualBar({
    super.key,
    required this.weight,
    required this.onIncrease,
    required this.onDecrease,
    required this.onWeightChange,
    required this.onMonetaryChange,
    required this.onLabelTap,
    required this.isSelected,
    required this.monetaryScale,
    this.percentageScale = 100.0,
  });

  @override
  State<PreferenceDualBar> createState() => _PreferenceDualBarState();
}

class _PreferenceDualBarState extends State<PreferenceDualBar> {
  bool _isEditingWeight = false;
  bool _isEditingMonetary = false;
  late TextEditingController _weightController;
  late TextEditingController _monetaryController;
  late FocusNode _weightFocusNode;
  late FocusNode _monetaryFocusNode;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController();
    _monetaryController = TextEditingController();
    _weightFocusNode = FocusNode();
    _monetaryFocusNode = FocusNode();
    
    _weightFocusNode.addListener(() {
      if (!_weightFocusNode.hasFocus && _isEditingWeight) {
        _saveWeightEdit();
      }
    });
    
    _monetaryFocusNode.addListener(() {
      if (!_monetaryFocusNode.hasFocus && _isEditingMonetary) {
        _saveMonetaryEdit();
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _monetaryController.dispose();
    _weightFocusNode.dispose();
    _monetaryFocusNode.dispose();
    super.dispose();
  }

  void _startEditingWeight() {
    setState(() {
      _isEditingWeight = true;
      _weightController.text = widget.weight.weight.toStringAsFixed(1);
    });
    _weightFocusNode.requestFocus();
    _weightController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _weightController.text.length,
    );
  }

  void _startEditingMonetary() {
    setState(() {
      _isEditingMonetary = true;
      _monetaryController.text = widget.weight.monetary.toStringAsFixed(0);
    });
    _monetaryFocusNode.requestFocus();
    _monetaryController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _monetaryController.text.length,
    );
  }

  void _saveWeightEdit() {
    final text = _weightController.text.trim();
    final newValue = double.tryParse(text);
    
    if (newValue != null && newValue >= 0 && newValue <= 100) {
      widget.onWeightChange(newValue);
    }
    
    setState(() {
      _isEditingWeight = false;
    });
  }

  void _saveMonetaryEdit() {
    final text = _monetaryController.text.trim();
    final newValue = double.tryParse(text);
    
    if (newValue != null && newValue >= 0) {
      widget.onMonetaryChange(newValue);
    }
    
    setState(() {
      _isEditingMonetary = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.weight.weight;
    final monetary = widget.weight.monetary;
    final barColor = widget.isSelected ? AppTheme.primary : Colors.blue[700]!;
    final monetaryColor = Colors.green[700]!;
    const maxBarHeight = 300.0;
    
    // Calculate bar heights
    final weightHeight = widget.percentageScale > 0
        ? (percentage / widget.percentageScale) * maxBarHeight
        : (percentage / 100) * maxBarHeight;
    final monetaryHeight = widget.monetaryScale > 0
        ? (monetary / widget.monetaryScale) * maxBarHeight
        : 0.0;

    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Increase button
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: widget.onIncrease,
            iconSize: 28,
            color: Colors.green[700],
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(height: 8),
          
          // Percentage and monetary display row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Weight percentage
              GestureDetector(
                onDoubleTap: _startEditingWeight,
                child: _isEditingWeight
                    ? SizedBox(
                        width: 50,
                        height: 28,
                        child: TextField(
                          controller: _weightController,
                          focusNode: _weightFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            suffixText: '%',
                            suffixStyle: const TextStyle(fontSize: 9),
                          ),
                          onSubmitted: (_) => _saveWeightEdit(),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: barColor, width: 1),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: barColor,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              
              // Monetary value
              GestureDetector(
                onDoubleTap: _startEditingMonetary,
                child: _isEditingMonetary
                    ? SizedBox(
                        width: 50,
                        height: 28,
                        child: TextField(
                          controller: _monetaryController,
                          focusNode: _monetaryFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            prefixText: '\$',
                            prefixStyle: const TextStyle(fontSize: 9),
                          ),
                          onSubmitted: (_) => _saveMonetaryEdit(),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: monetaryColor, width: 1),
                        ),
                        child: Text(
                          '\$${_formatMonetary(monetary)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: monetaryColor,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Dual bars side by side
          SizedBox(
            height: maxBarHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Weight bar (blue)
                Container(
                  width: 30,
                  height: maxBarHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 30,
                      height: weightHeight.clamp(0, maxBarHeight),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Monetary bar (green)
                Container(
                  width: 30,
                  height: maxBarHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 30,
                      height: monetaryHeight.clamp(0, maxBarHeight),
                      decoration: BoxDecoration(
                        color: monetaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Decrease button
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.onDecrease,
            iconSize: 28,
            color: Colors.red[700],
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(height: 8),
          
          // Label with info icon
          InkWell(
            onTap: widget.onLabelTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.weight.preference.shortLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected ? AppTheme.primary : Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: widget.isSelected ? AppTheme.primary : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ],
    );
  }

  String _formatMonetary(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}
