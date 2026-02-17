import 'package:flutter/material.dart';
import '../../../../core/constants/kyc_types.dart';
import 'kyc_document_upload_screen.dart';

class KYCOnboardingScreen extends StatelessWidget {
  const KYCOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification KYC'),
        backgroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user,
                    size: 50,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Vérification d\'identité',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'Pour garantir la sécurité de tous, nous devons vérifier votre identité avant que vous puissiez commencer à conduire.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Section: Documents Required
              Text(
                'Documents requis',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              _buildDocumentRequirement(
                context,
                icon: Icons.credit_card,
                title: 'Carte d\'identité ou Passeport',
                description: 'Document d\'identité valide avec photo',
                required: true,
              ),
              const SizedBox(height: 12),

              _buildDocumentRequirement(
                context,
                icon: Icons.drive_eta,
                title: 'Permis de conduire',
                description: 'Permis en cours de validité',
                required: true,
              ),
              const SizedBox(height: 12),

              _buildDocumentRequirement(
                context,
                icon: Icons.person,
                title: 'Photo selfie',
                description: 'Photo claire de votre visage',
                required: true,
              ),
              const SizedBox(height: 12),

              _buildDocumentRequirement(
                context,
                icon: Icons.description,
                title: 'Carte grise du véhicule',
                description: 'Document d\'immatriculation (optionnel)',
                required: false,
              ),
              const SizedBox(height: 12),

              _buildDocumentRequirement(
                context,
                icon: Icons.shield,
                title: 'Assurance',
                description: 'Certificat d\'assurance (optionnel)',
                required: false,
              ),
              const SizedBox(height: 32),

              // Section: Important Notes
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Important',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoPoint('Photos claires et lisibles'),
                    _buildInfoPoint('Documents en cours de validité'),
                    _buildInfoPoint('Vérification sous 24-48h'),
                    _buildInfoPoint('Vos données sont sécurisées'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // CTA Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const KYCDocumentUploadScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Commencer la vérification',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Skip button (optional)
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Plus tard',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentRequirement(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool required,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (required)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Requis',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
