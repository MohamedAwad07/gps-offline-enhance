import 'package:flutter/material.dart';
import 'package:learning/services/barometer/barometer_validation_service.dart';

/// Card to display barometer validation status
class BarometerValidationCard extends StatefulWidget {
  const BarometerValidationCard({super.key});

  @override
  State<BarometerValidationCard> createState() =>
      _BarometerValidationCardState();
}

class _BarometerValidationCardState extends State<BarometerValidationCard> {
  BarometerValidationResult? _validationResult;
  bool _isValidating = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.verified, color: _getValidationColor()),
                const SizedBox(width: 8),
                Text(
                  'Barometer Validation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_validationResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getValidationColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getValidationColor().withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _validationResult!.accuracyGrade,
                      style: TextStyle(
                        color: _getValidationColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Validation Button
            ElevatedButton.icon(
              onPressed: _isValidating ? null : _performValidation,
              icon: _isValidating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isValidating ? 'Validating...' : 'Validate Sensor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            if (_validationResult != null) ...[
              const SizedBox(height: 16),
              _buildValidationResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationResults() {
    final result = _validationResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Message
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getValidationColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getValidationColor().withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                result.isValid ? Icons.check_circle : Icons.error,
                color: _getValidationColor(),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.message,
                  style: TextStyle(
                    color: _getValidationColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Pressure Comparison
        if (result.barometerPressure != null) ...[
          _buildPressureRow(
            'Hardware Barometer',
            result.barometerPressure!,
            Icons.sensors,
            Colors.green,
          ),
          const SizedBox(height: 4),
        ],

        if (result.weatherPressure != null) ...[
          _buildPressureRow(
            'Weather Station${result.weatherSource != null ? " (${result.weatherSource})" : ""}',
            result.weatherPressure!,
            Icons.cloud,
            Colors.blue,
          ),
          const SizedBox(height: 4),
        ],

        if (result.difference != null) ...[
          _buildPressureRow(
            'Difference',
            result.difference!,
            Icons.compare_arrows,
            _getValidationColor(),
            showUnit: false,
            prefix: '±',
            suffix: ' hPa',
          ),
        ],

        const SizedBox(height: 12),

        // Recommendations
        const Text(
          'Recommendations:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...BarometerValidationService.getValidationRecommendations(result).map(
          (rec) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Colors.grey)),
                Expanded(
                  child: Text(
                    rec,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPressureRow(
    String label,
    double value,
    IconData icon,
    Color color, {
    bool showUnit = true,
    String prefix = '',
    String suffix = '',
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '$prefix${value.toStringAsFixed(1)}${showUnit ? ' hPa' : suffix}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getValidationColor() {
    if (_validationResult == null) return Colors.grey;

    if (_validationResult!.isValid) {
      if (_validationResult!.difference != null) {
        if (_validationResult!.difference! <= 2.0) return Colors.green;
        if (_validationResult!.difference! <= 5.0) return Colors.lightGreen;
      }
      return Colors.green;
    } else {
      if (_validationResult!.difference != null) {
        if (_validationResult!.difference! <= 10.0) return Colors.orange;
      }
      return Colors.red;
    }
  }

  Future<void> _performValidation() async {
    setState(() {
      _isValidating = true;
    });

    try {
      final result = await BarometerValidationService.validateReading();
      setState(() {
        _validationResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Validation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }
}
