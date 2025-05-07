import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../utils/pc_service.dart';

class QRTestScreen extends StatefulWidget {
  const QRTestScreen({Key? key}) : super(key: key);

  @override
  _QRTestScreenState createState() => _QRTestScreenState();
}

class _QRTestScreenState extends State<QRTestScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isScanning = true;
  String result = '';
  Map<String, dynamic>? pcDetails;
  Map<String, dynamic>? labDetails;
  bool isLoading = false;
  String errorMessage = '';

  final PCService _pcService = PCService();

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code != null && isScanning) {
        setState(() {
          isScanning = false;
          result = scanData.code!;
          isLoading = true;
          errorMessage = '';
        });

        try {
          // Parse the QR code to get the PC ID
          final pcId = int.parse(result);

          // Get PC details
          final pc = await _pcService.getPCById(pcId);
          if (mounted) {
            setState(() {
              pcDetails = pc;
            });
          }

          // Get laboratory details
          if (pc['laboratoire'] != null) {
            final lab = await _pcService.getLaboratoryById(pc['laboratoire']);
            if (mounted) {
              setState(() {
                labDetails = lab;
              });
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              errorMessage = 'Error: $e';
            });
          }
        } finally {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        }
      }
    });
  }

  void _resetScanner() {
    setState(() {
      isScanning = true;
      result = '';
      pcDetails = null;
      labDetails = null;
      errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code Scanner Test')),
      body: Column(
        children: [
          if (isScanning)
            Expanded(
              flex: 5,
              child: QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Colors.blue,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 300,
                ),
              ),
            ),
          if (!isScanning)
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QR Code Result: $result',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Text(
                          errorMessage,
                          style: TextStyle(color: Colors.red[800]),
                        ),
                      )
                    else if (pcDetails != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PC Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('ID', '${pcDetails!['id']}'),
                            _buildDetailRow('Poste', '${pcDetails!['poste']}'),
                            _buildDetailRow(
                              'S/N',
                              '${pcDetails!['sn_inventaire']}',
                            ),
                            _buildDetailRow('Écran', '${pcDetails!['ecran']}'),
                            _buildDetailRow(
                              'Laboratoire ID',
                              '${pcDetails!['laboratoire']}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (labDetails != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Laboratory Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow('ID', '${labDetails!['id']}'),
                              _buildDetailRow('Nom', '${labDetails!['nom']}'),
                              _buildDetailRow(
                                'Modèle',
                                '${labDetails!['modele_postes']}',
                              ),
                              _buildDetailRow(
                                'Processeur',
                                '${labDetails!['processeur']}',
                              ),
                              _buildDetailRow(
                                'RAM',
                                '${labDetails!['memoire_ram']}',
                              ),
                              _buildDetailRow(
                                'Stockage',
                                '${labDetails!['stockage']}',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(
            flex: 1,
            child: Center(
              child: ElevatedButton(
                onPressed: isScanning ? null : _resetScanner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Scan Again'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
