import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'welcome_screen.dart';
import 'profil.dart';
import 'services/reclamation_service.dart';
import 'services/laboratory_service.dart';

class EnseignantPage extends StatefulWidget {
  const EnseignantPage({Key? key}) : super(key: key);

  @override
  _EnseignantPageState createState() => _EnseignantPageState();
}

class _EnseignantPageState extends State<EnseignantPage> {
  int _currentIndex = 0;
  QRViewController? _qrViewController;
  bool _isScanning = false;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  // User data
  String username = '';
  int userId = 0;
  String userType = '';
  String firstName = '';
  String lastName = '';
  String? imageUrl;

  // Services
  final ReclamationService _reclamationService = ReclamationService();
  final LaboratoryService _laboratoryService = LaboratoryService();

  // Data
  List<dynamic> allReclamations = [];
  List<dynamic> userReclamations = [];
  List<dynamic> laboratories = [];
  List<dynamic> filteredLaboratories = [];
  Map<int, List<dynamic>> labPCs = {};
  List<dynamic> filteredReclamations = [];
  String searchKeywords = '';
  String labSearchKeywords = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Search laboratories by name or other attributes
  void _searchLaboratories(String query) {
    setState(() {
      labSearchKeywords = query;
      if (query.isEmpty) {
        filteredLaboratories = laboratories;
      } else {
        filteredLaboratories =
            laboratories.where((lab) {
              final name = lab['nom']?.toString().toLowerCase() ?? '';
              final model =
                  lab['modele_postes']?.toString().toLowerCase() ?? '';
              final processor =
                  lab['processeur']?.toString().toLowerCase() ?? '';
              final ram = lab['memoire_ram']?.toString().toLowerCase() ?? '';
              final storage = lab['stockage']?.toString().toLowerCase() ?? '';

              final searchLower = query.toLowerCase();

              return name.contains(searchLower) ||
                  model.contains(searchLower) ||
                  processor.contains(searchLower) ||
                  ram.contains(searchLower) ||
                  storage.contains(searchLower);
            }).toList();
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');

      // For debugging, print the token to check user ID
      final token = prefs.getString('access_token');
      if (token != null) {
        try {
          // Decode the JWT token to get user ID
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            final normalized = base64Url.normalize(payload);
            final decoded = utf8.decode(base64Url.decode(normalized));
            final data = jsonDecode(decoded);

            // Set user ID from token
            setState(() {
              userId = data['user_id'] ?? 0;
            });
          }
        } catch (e) {
          // Handle token decoding error silently
        }
      }

      if (userJson != null) {
        final userData = jsonDecode(userJson);
        setState(() {
          username = userData['username'] ?? '';
          // Only set userId if not already set from token
          if (userId == 0) {
            userId = userData['id'] ?? 0;
          }
          userType = userData['role'] ?? '';
          firstName = userData['first_name'] ?? '';
          lastName = userData['last_name'] ?? '';
          imageUrl = userData['image'];
          print("DEBUG - Loaded user image URL: $imageUrl");
        });

        // Load data based on user type
        await _loadData();
      } else {
        // Still load data even if no user data is found
        await _loadData();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadData() async {
    try {
      print('Loading data for user: $username, ID: $userId, Type: $userType');

      // Load all reclamations (for all users)
      print('Loading all reclamations');
      try {
        final reclamations = await _reclamationService.getAllReclamations();
        print('Loaded ${reclamations.length} reclamations');
        print('DEBUG - All reclamations data: ${jsonEncode(reclamations)}');
        if (mounted) {
          setState(() {
            allReclamations = reclamations;
            filteredReclamations =
                reclamations; // Initialize filtered reclamations
          });
        }
      } catch (e) {
        print('Error loading all reclamations: $e');
      }

      // Load user reclamations (for all users)
      if (userId > 0) {
        print('Loading reclamations for user ID: $userId');
        try {
          final reclamations = await _reclamationService.getUserReclamations(
            userId,
          );
          print('Loaded ${reclamations.length} user reclamations');
          print('DEBUG - User reclamations data: ${jsonEncode(reclamations)}');

          // Check if reclamations is empty
          if (reclamations.isEmpty) {
            print('DEBUG - No reclamations found for user ID: $userId');
          } else {
            // Print details of each reclamation
            for (var i = 0; i < reclamations.length; i++) {
              print('DEBUG - Reclamation $i: ${jsonEncode(reclamations[i])}');
              print('DEBUG - Reclamation $i ID: ${reclamations[i]['id']}');
              print(
                'DEBUG - Reclamation $i Status: ${reclamations[i]['status'] ?? reclamations[i]['statut']}',
              );
              print(
                'DEBUG - Reclamation $i Category: ${reclamations[i]['category']}',
              );
            }
          }

          if (mounted) {
            setState(() {
              userReclamations = reclamations;
            });
          }
        } catch (e) {
          print('Error loading user reclamations: $e');
          print('DEBUG - Error details: $e');
          // If we can't load user reclamations, initialize with empty list
          if (mounted) {
            setState(() {
              userReclamations = [];
            });
          }
        }
      }

      // Load laboratories (for all users)
      print('Loading laboratories');
      try {
        final labs = await _laboratoryService.getAllLaboratories();
        print('Loaded ${labs.length} laboratories: $labs');
        if (mounted) {
          setState(() {
            laboratories = labs;
            filteredLaboratories = labs; // Initialize filtered labs
          });
        }

        // Load PCs for each laboratory
        for (var lab in laboratories) {
          if (lab['id'] != null) {
            print('Loading PCs for laboratory ID: ${lab['id']}');
            try {
              final pcs = await _laboratoryService.getPCsByLaboratory(
                lab['id'],
              );
              print('Loaded ${pcs.length} PCs for laboratory ID: ${lab['id']}');
              if (mounted) {
                setState(() {
                  labPCs[lab['id']] = pcs;
                });
              }
            } catch (e) {
              print('Error loading PCs for laboratory ID ${lab['id']}: $e');
            }
          }
        }
      } catch (e) {
        print('Error loading laboratories: $e');
      }
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Image.asset(
                  "assets/projet.jpg",
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width - 40,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                _buildWavyHeader(),
                _buildProfileSection(),
                _buildMainMenu(),
                _buildContentSection(),
              ],
            ),
          ),
          if (_isScanning) _buildQRScannerOverlay(),
        ],
      ),
    );
  }

  void _showLabDetails(BuildContext context, String labName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Détails techniques - $labName',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (labName == 'Labo 1') ...[
                  _buildDetailSection('Configuration technique', [
                    _buildDetailItem(Icons.computer, 'Modèle: HP Z240 Xeon'),
                    _buildDetailItem(Icons.memory, 'Mémoire RAM: 16 Go DDR4'),
                    _buildDetailItem(
                      Icons.speed,
                      'Processeur: Xeon E3-1240 v5 / 3.5 GHz',
                    ),
                    _buildDetailItem(
                      Icons.storage,
                      'Stockage: 256 Go SSD + 1 To HDD',
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildDetailSection('Postes (2)', [_buildPosteTableLab1()]),
                ] else ...[
                  _buildDetailSection('Configuration technique', [
                    _buildDetailItem(
                      Icons.computer,
                      'Modèle: Dell OptiPlex 7080',
                    ),
                    _buildDetailItem(Icons.memory, 'Mémoire RAM: 32 Go DDR4'),
                    _buildDetailItem(
                      Icons.speed,
                      'Processeur: Intel Core i7-10700 / 2.9 GHz',
                    ),
                    _buildDetailItem(
                      Icons.storage,
                      'Stockage: 512 Go SSD NVMe',
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildDetailSection('Postes (1)', [_buildPosteTableLab2()]),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Fermer',
                style: GoogleFonts.poppins(color: Colors.blue),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
    _qrViewController?.dispose();
    _qrViewController = null;

    // Make sure any loading dialogs are closed
    while (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    _qrViewController = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (mounted && scanData.code != null) {
        _stopScanning(); // Stop scanning immediately to prevent multiple scans

        try {
          // Parse the QR code to get the PC ID
          final pcId = int.parse(scanData.code!);

          // Show loading dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => const AlertDialog(
                  title: Text('Chargement...'),
                  content: Center(
                    heightFactor: 1,
                    child: CircularProgressIndicator(),
                  ),
                ),
          );

          try {
            // Get PC details
            final pcDetails = await _laboratoryService.getPCById(pcId);

            // Get laboratory details
            final labId = pcDetails['laboratoire'];
            final labDetails = await _laboratoryService.getLaboratoryDetails(
              labId,
            );

            // Check if still mounted before proceeding
            if (mounted) {
              // Close loading dialog
              Navigator.of(context).pop();

              // Show problem report dialog
              await _showProblemReportDialog(pcDetails, labDetails);
            }
          } catch (e) {
            // Check if still mounted before proceeding
            if (mounted) {
              // Close loading dialog
              Navigator.of(context).pop();

              // Show error dialog
              await showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Erreur'),
                      content: Text(
                        'Impossible de charger les détails du PC: $e',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
              );
            }
          }
        } catch (e) {
          // Show error dialog for invalid QR code
          if (mounted) {
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('QR Code invalide'),
                    content: Text(
                      'Le QR code scanné n\'est pas valide: ${scanData.code}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
            );
          }
        }
      }
    });
  }

  Future<void> _showProblemReportDialog(
    Map<String, dynamic> pcDetails,
    Map<String, dynamic> labDetails,
  ) async {
    // Problem type selection
    String problemType = 'materiel'; // Default to hardware
    String? hardwareProblem;
    String? softwareProblem;
    // We keep otherProblem for the UI but we won't use it in the new format
    String? otherProblem;
    String description = '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Signaler un problème',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailSection('Informations', [
                      _buildDetailItem(
                        Icons.computer,
                        'Poste: ${pcDetails['poste']}',
                      ),
                      _buildDetailItem(
                        Icons.location_on,
                        'Laboratoire: ${labDetails['nom']}',
                      ),
                      _buildDetailItem(
                        Icons.numbers,
                        'S/N: ${pcDetails['sn_inventaire']}',
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailSection('Type de problème', [
                      Row(
                        children: [
                          Radio<String>(
                            value: 'materiel',
                            groupValue: problemType,
                            onChanged: (value) {
                              setState(() {
                                problemType = value!;
                                softwareProblem = null;
                              });
                            },
                          ),
                          const Text('Matériel'),
                          const SizedBox(width: 16),
                          Radio<String>(
                            value: 'logiciel',
                            groupValue: problemType,
                            onChanged: (value) {
                              setState(() {
                                problemType = value!;
                                hardwareProblem = null;
                              });
                            },
                          ),
                          const Text('Logiciel'),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 16),
                    if (problemType == 'materiel')
                      _buildDetailSection('Problème matériel', [
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Sélectionnez le problème',
                            border: OutlineInputBorder(),
                          ),
                          value: hardwareProblem,
                          items: const [
                            DropdownMenuItem(
                              value: 'clavier',
                              child: Text('Clavier'),
                            ),
                            DropdownMenuItem(
                              value: 'souris',
                              child: Text('Souris'),
                            ),
                            DropdownMenuItem(
                              value: 'ecran',
                              child: Text('Écran'),
                            ),
                            DropdownMenuItem(
                              value: 'imprimante',
                              child: Text('Imprimante'),
                            ),
                            DropdownMenuItem(
                              value: 'scanner',
                              child: Text('Scanner'),
                            ),
                            DropdownMenuItem(
                              value: 'reseau',
                              child: Text('Réseau'),
                            ),
                            DropdownMenuItem(
                              value: 'autre',
                              child: Text('Autre'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              hardwareProblem = value;
                            });
                          },
                        ),
                        if (hardwareProblem == 'autre')
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Précisez le problème',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                otherProblem = value;
                              },
                            ),
                          ),
                      ])
                    else if (problemType == 'logiciel')
                      _buildDetailSection('Problème logiciel', [
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Sélectionnez le problème',
                            border: OutlineInputBorder(),
                          ),
                          value: softwareProblem,
                          items: const [
                            DropdownMenuItem(
                              value: 'os',
                              child: Text('Système d\'exploitation'),
                            ),
                            DropdownMenuItem(
                              value: 'reseau',
                              child: Text('Problème réseau'),
                            ),
                            DropdownMenuItem(
                              value: 'antivirus',
                              child: Text('Antivirus'),
                            ),
                            DropdownMenuItem(
                              value: 'installation',
                              child: Text('Installation de logiciel'),
                            ),
                            DropdownMenuItem(
                              value: 'autre',
                              child: Text('Autre'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              softwareProblem = value;
                            });
                          },
                        ),
                        if (softwareProblem == 'autre')
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Précisez le problème',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                otherProblem = value;
                              },
                            ),
                          ),
                      ]),
                    const SizedBox(height: 16),
                    _buildDetailSection('Description', [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Description du problème',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          description = value;
                        },
                      ),
                    ]),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text(
                    'Annuler',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                  onPressed: () {
                    // Make sure we're not showing any loading dialogs
                    while (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                TextButton(
                  child: Text(
                    'Soumettre',
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                  onPressed: () async {
                    // Validate form
                    if ((problemType == 'materiel' &&
                            hardwareProblem == null) ||
                        (problemType == 'logiciel' &&
                            softwareProblem == null) ||
                        description.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez remplir tous les champs'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Get user ID from token
                    int currentUserId = userId;
                    if (currentUserId <= 0) {
                      // Try to get user ID from token
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('access_token');
                        if (token != null) {
                          final parts = token.split('.');
                          if (parts.length == 3) {
                            final payload = parts[1];
                            final normalized = base64Url.normalize(payload);
                            final decoded = utf8.decode(
                              base64Url.decode(normalized),
                            );
                            final data = jsonDecode(decoded);
                            if (data.containsKey('user_id')) {
                              currentUserId = data['user_id'];
                              print(
                                'DEBUG - Using user ID from token: $currentUserId',
                              );
                            }
                          }
                        }
                      } catch (e) {
                        print('DEBUG - Error getting user ID from token: $e');
                      }
                    }

                    // Create reclamation data
                    final reclamationData = {
                      "lieu": 'labo',
                      "lieu_specifique": labDetails['nom'],
                      "category": "pc",
                      "description_generale": "Problème avec un ordinateur",
                      "pc_details": {
                        "pc_id": pcDetails['id'],
                        "type_probleme":
                            problemType == 'materiel' ? "materiel" : "logiciel",
                        // For hardware problems
                        "materiel":
                            problemType == 'materiel'
                                ? (hardwareProblem == 'autre'
                                    ? otherProblem
                                    : hardwareProblem)
                                : "",
                        // For software problems
                        "logiciel":
                            problemType == 'logiciel'
                                ? (softwareProblem == 'autre'
                                    ? otherProblem
                                    : softwareProblem)
                                : "",
                        // Description for all problems
                        "description_probleme": description,
                      },
                      // Use both status and statut to handle backend inconsistency
                      "status": "en_attente",
                      "statut": "en_attente",
                      "user": currentUserId,
                      "laboratoire": labDetails['id'],
                      // Set equipment field to 0 as mentioned in memories
                      "equipment": 0,
                    };

                    // Submit reclamation
                    _submitReclamation(reclamationData);

                    // Check if still mounted before popping
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReclamation(Map<String, dynamic> reclamationData) async {
    // Create a flag to track if we've shown the loading dialog
    bool loadingDialogShown = false;

    // Show loading dialog
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          loadingDialogShown = true;
          return AlertDialog(
            title: const Text('Envoi en cours...'),
            content: const Center(
              heightFactor: 1,
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
    } catch (e) {
      // If showing the dialog fails, continue without it
      loadingDialogShown = false;
    }

    try {
      // Submit reclamation
      await _reclamationService.createReclamation(reclamationData);

      // Check if still mounted before proceeding
      if (!mounted) return;

      // Close loading dialog if it's still showing
      if (loadingDialogShown && Navigator.canPop(context)) {
        Navigator.of(context).pop();
        loadingDialogShown = false;
      }

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Succès'),
                content: const Text(
                  'Votre réclamation a été soumise avec succès.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('OK'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _refreshData(); // Refresh data to show the new reclamation

                      // Switch to the "Mes Réclamations" tab
                      setState(() {
                        _currentIndex = 2;
                      });
                    },
                    child: const Text('Voir mes réclamations'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      // Check if still mounted before proceeding
      if (!mounted) return;

      // Close loading dialog if it's still showing
      if (loadingDialogShown && Navigator.canPop(context)) {
        Navigator.of(context).pop();
        loadingDialogShown = false;
      }

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Erreur'),
                content: Text('Impossible de soumettre la réclamation: $e'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  @override
  void dispose() {
    _qrViewController?.dispose();
    super.dispose();
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildPosteTableLab1() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.grey[300]!),
        ),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(3),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.blue[50]),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'POSTE',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'S/N',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'LOGICIELS',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          TableRow(
            children: [
              Padding(padding: const EdgeInsets.all(8), child: Text('P1')),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('CZC7067NVG'),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Visual Studio 2022\nEclipse IDE\nWAMP Server\nOracle VM VirtualBox\nMicrosoft Office',
                ),
              ),
            ],
          ),
          TableRow(
            children: [
              Padding(padding: const EdgeInsets.all(8), child: Text('P2')),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('CZC7067NVH'),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Android Studio\nVisual Studio Code\nPython 3.9\nGit\nNode.js',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPosteTableLab2() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.grey[300]!),
        ),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(3),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.blue[50]),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'POSTE',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'S/N',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'LOGICIELS',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          TableRow(
            children: [
              Padding(padding: const EdgeInsets.all(8), child: Text('P1')),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('D3LL4921XMP'),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Cisco Packet Tracer\nWireshark\nPutty\nVirtualBox\nMicrosoft Office',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQRScannerOverlay() {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.7))),
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Scannez le QR code du problème',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 250,
                height: 250,
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.blue,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 250,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _stopScanning,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Annuler le scan'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWavyHeader() {
    return SizedBox(
      height: 80,
      child: Stack(
        children: [
          ClipPath(
            clipper: WaveClipper(),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue[900]!.withOpacity(0.8),
                    Colors.lightBlue[400]!.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: 20,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/isimg_logo.png',
                      height: 30,
                      width: 30,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        "Institut Supérieur d'Informatique\net de Multimédia de Gabès",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                imageUrl != null && imageUrl!.isNotEmpty
                    ? Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                        image: DecorationImage(
                          image: NetworkImage(imageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                    : Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                        color: Colors.blue[100],
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.blue[800],
                        size: 30,
                      ),
                    ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userType.isNotEmpty ? userType : 'Enseignant(e)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        firstName.isNotEmpty || lastName.isNotEmpty
                            ? '$firstName $lastName'
                            : (username.isNotEmpty ? username : 'User'),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildCircleButton(
                icon: Icons.person_outline,
                color: Colors.blue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                },
              ),
              const SizedBox(width: 10),
              _buildCircleButton(
                icon: Icons.logout,
                color: Colors.red,
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => WelcomeScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: Colors.white),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildMainMenu() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuButton('Toutes les Réclamations', Icons.list_alt, 0),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuButton('Fiche Technique', Icons.computer, 1),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuButton('Mes Réclamations', Icons.person_outline, 2),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    try {
      // Check token validity
      final isTokenValid = await _reclamationService.checkToken();

      if (!isTokenValid) {
        // If token is not valid, show login screen
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Session expirée'),
                  content: const Text(
                    'Votre session a expiré. Veuillez vous reconnecter.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
        return;
      }

      // Then load the data
      await _loadData();
    } catch (e) {
      print('Error refreshing data: $e');

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Erreur'),
                content: Text('Impossible de charger les données: $e'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  Widget _buildMenuButton(String text, IconData icon, int index) {
    return ListTile(
      leading: Icon(
        icon,
        color: _currentIndex == index ? Colors.blue : Colors.grey[600],
      ),
      title: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight:
              _currentIndex == index ? FontWeight.w600 : FontWeight.normal,
          color: _currentIndex == index ? Colors.blue[800] : Colors.grey[700],
        ),
      ),
      trailing:
          _currentIndex == index
              ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.blue,
                ),
              )
              : null,
      onTap: () {
        setState(() => _currentIndex = index);
        _refreshData(); // Refresh data when tab is changed
      },
    );
  }

  Widget _buildContentSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Only show search field for laboratories tab
          if (_currentIndex == 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher une fiche technique...',
                  prefixIcon: const Icon(Icons.search, color: Colors.blue),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
                onChanged: _searchLaboratories,
              ),
            ),

          if (_currentIndex == 0)
            Column(
              children: [
                // Search bar for reclamations
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher par mots-clés...',
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchKeywords = value;
                      });
                      _searchReclamations(value);
                    },
                  ),
                ),
                // Refresh button for "Toutes les Réclamations"
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _refreshData,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Actualiser les réclamations"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

          if (_currentIndex == 2)
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startScanning,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scanner un problème"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _refreshData,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Actualiser mes réclamations"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: MediaQuery.of(context).size.height * 0.4,
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  // Search reclamations by keywords
  Future<void> _searchReclamations(String keywords) async {
    try {
      if (keywords.isEmpty) {
        // If search is empty, show all terminated reclamations
        setState(() {
          filteredReclamations = allReclamations;
        });
        return;
      }

      // Show loading indicator
      setState(() {
        filteredReclamations = [];
      });

      // Search reclamations by keywords
      final results = await _reclamationService.searchReclamationsByKeywords(
        keywords,
      );

      // Update UI with results
      if (mounted) {
        setState(() {
          filteredReclamations = results;
        });
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la recherche: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show intervention details dialog
  void _showInterventionDetails(Map<String, dynamic> reclamation) {
    // Get interventions from the reclamation
    final interventions =
        reclamation['matching_interventions'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Détails de l\'intervention',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailSection('Réclamation', [
                  _buildDetailItem(
                    Icons.info_outline,
                    'ID: ${reclamation['id']}',
                  ),
                  _buildDetailItem(
                    Icons.category,
                    'Catégorie: ${reclamation['category'] ?? 'Non spécifiée'}',
                  ),
                  _buildDetailItem(
                    Icons.location_on,
                    'Lieu: ${reclamation['lieu'] ?? 'Non spécifié'}',
                  ),
                  _buildDetailItem(
                    Icons.calendar_today,
                    'Date: ${reclamation['date_creation']?.substring(0, 10) ?? 'Non spécifiée'}',
                  ),
                ]),
                const SizedBox(height: 16),
                _buildDetailSection('Interventions (${interventions.length})', [
                  if (interventions.isEmpty)
                    const Text('Aucune intervention trouvée')
                  else
                    ...interventions.map(
                      (intervention) => _buildInterventionItem(intervention),
                    ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Fermer',
                style: GoogleFonts.poppins(color: Colors.blue),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Build intervention item
  Widget _buildInterventionItem(Map<String, dynamic> intervention) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (intervention['probleme_constate'] != null)
            _buildDetailItem(
              Icons.error_outline,
              'Problème: ${intervention['probleme_constate']}',
            ),
          if (intervention['analyse_cause'] != null)
            _buildDetailItem(
              Icons.search,
              'Cause: ${intervention['analyse_cause']}',
            ),
          if (intervention['actions_entreprises'] != null)
            _buildDetailItem(
              Icons.build,
              'Actions: ${intervention['actions_entreprises']}',
            ),
          if (intervention['recommandations'] != null)
            _buildDetailItem(
              Icons.lightbulb_outline,
              'Recommandations: ${intervention['recommandations']}',
            ),
          if (intervention['mots_cles'] != null)
            _buildDetailItem(
              Icons.label_outline,
              'Mots-clés: ${intervention['mots_cles']}',
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentIndex) {
      case 0:
        // Show all reclamations for all users
        if (searchKeywords.isNotEmpty) {
          // If search is active, show filtered reclamations
          if (filteredReclamations.isEmpty) {
            return const Center(
              child: Text('Aucune réclamation trouvée pour cette recherche'),
            );
          }
          return _buildReclamationsListFromAPI(filteredReclamations);
        } else {
          // Otherwise show all terminated reclamations
          if (allReclamations.isEmpty) {
            return const Center(child: Text('Aucune réclamation trouvée'));
          }
          return _buildReclamationsListFromAPI(allReclamations);
        }

      case 1:
        if (laboratories.isEmpty) {
          return const Center(child: Text('Aucun laboratoire trouvé'));
        }

        if (labSearchKeywords.isNotEmpty && filteredLaboratories.isEmpty) {
          return const Center(
            child: Text('Aucun laboratoire trouvé pour cette recherche'),
          );
        }

        return _buildLabosListFromAPI();

      case 2:
        if (userReclamations.isEmpty) {
          return const Center(
            child: Text('Vous n\'avez pas encore créé de réclamation'),
          );
        }

        return _buildReclamationsListFromAPI(userReclamations);

      default:
        return Container();
    }
  }

  Widget _buildReclamationsListFromAPI(List<dynamic> reclamations) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: reclamations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final reclamation = reclamations[index];
        // Handle both 'status' and 'statut' fields (English/French)
        final status = reclamation['status'] ?? reclamation['statut'];
        final bool isCompleted = status == 'termine';

        return Container(
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCompleted ? Colors.green[100]! : Colors.red[100]!,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green[100] : Colors.red[100],
              ),
              child: Center(
                child:
                    isCompleted
                        ? Lottie.asset(
                          'assets/rouge.json',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                        )
                        : Icon(Icons.close, color: Colors.red[800], size: 18),
              ),
            ),
            title: Text(
              'Réclamation #${reclamation['id']} - ${reclamation['category'] ?? 'Non catégorisée'}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.blueGrey[800],
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lieu: ${reclamation['lieu'] ?? 'Non spécifié'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Statut: ${_getStatusText(reclamation['status'] ?? reclamation['statut'])}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Date: ${reclamation['date_creation']?.substring(0, 10) ?? 'Non spécifiée'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                // Show keywords if available from search
                if (reclamation['matching_interventions'] != null)
                  Text(
                    'Mots-clés: ${_getKeywordsFromInterventions(reclamation['matching_interventions'])}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.blue,
            ),
            onTap: () {
              // Show intervention details when reclamation is clicked
              _showInterventionDetails(reclamation);
            },
          ),
        );
      },
    );
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'en_attente':
        return 'En attente';
      case 'en_cours':
        return 'En cours';
      case 'termine':
        return 'Terminé';
      default:
        return 'Inconnu';
    }
  }

  // Extract keywords from interventions
  String _getKeywordsFromInterventions(List<dynamic>? interventions) {
    if (interventions == null || interventions.isEmpty) {
      return '';
    }

    // Collect all keywords from interventions
    final List<String> allKeywords = [];
    for (var intervention in interventions) {
      if (intervention['mots_cles'] != null &&
          intervention['mots_cles'].toString().isNotEmpty) {
        allKeywords.add(intervention['mots_cles'].toString());
      }
    }

    // Return comma-separated keywords
    return allKeywords.join(', ');
  }

  Widget _buildLabosListFromAPI() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: filteredLaboratories.length,
      itemBuilder: (context, index) {
        final laboratory = filteredLaboratories[index];
        final labId = laboratory['id'];
        final pcs = labPCs[labId] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            laboratory['nom'] ?? 'Laboratoire sans nom',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          Text(
                            '${pcs.length} postes • ${laboratory['modele_postes'] ?? 'Non spécifié'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed:
                          () =>
                              _showLabDetailsFromAPI(context, laboratory, pcs),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDetailItem(
                  Icons.memory,
                  'CPU: ${laboratory['processeur'] ?? 'Non spécifié'}',
                ),
                _buildDetailItem(
                  Icons.memory,
                  'RAM: ${laboratory['memoire_ram'] ?? 'Non spécifiée'}',
                ),
                _buildDetailItem(
                  Icons.storage,
                  'Stockage: ${laboratory['stockage'] ?? 'Non spécifié'}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLabDetailsFromAPI(
    BuildContext context,
    Map<String, dynamic> laboratory,
    List<dynamic> pcs,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Détails techniques - ${laboratory['nom'] ?? 'Laboratoire'}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailSection('Configuration technique', [
                  _buildDetailItem(
                    Icons.computer,
                    'Modèle: ${laboratory['modele_postes'] ?? 'Non spécifié'}',
                  ),
                  _buildDetailItem(
                    Icons.memory,
                    'Mémoire RAM: ${laboratory['memoire_ram'] ?? 'Non spécifiée'}',
                  ),
                  _buildDetailItem(
                    Icons.speed,
                    'Processeur: ${laboratory['processeur'] ?? 'Non spécifié'}',
                  ),
                  _buildDetailItem(
                    Icons.storage,
                    'Stockage: ${laboratory['stockage'] ?? 'Non spécifié'}',
                  ),
                ]),
                const SizedBox(height: 16),
                _buildDetailSection('Postes (${pcs.length})', [
                  _buildPosteTableFromAPI(pcs),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Fermer',
                style: GoogleFonts.poppins(color: Colors.blue),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPosteTableFromAPI(List<dynamic> pcs) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.grey[300]!),
        ),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(3),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.blue[50]),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'POSTE',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'S/N',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'LOGICIELS',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (pcs.isEmpty)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Aucun PC', style: GoogleFonts.poppins()),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('-', style: GoogleFonts.poppins()),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('-', style: GoogleFonts.poppins()),
                ),
              ],
            )
          else
            ...pcs.map(
              (pc) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      pc['poste'] ?? '-',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      pc['sn_inventaire'] ?? '-',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      pc['logiciels_installes'] ?? '-',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 20);

    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 15);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 3 / 4, size.height - 30);
    var secondEndPoint = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
