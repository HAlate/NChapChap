import 'package:flutter/material.dart';

/// Dialog pour composer et envoyer un message
class ComposeMessageDialog extends StatefulWidget {
  final String receiverName;
  final Function(String message) onSend;

  const ComposeMessageDialog({
    super.key,
    required this.receiverName,
    required this.onSend,
  });

  @override
  State<ComposeMessageDialog> createState() => _ComposeMessageDialogState();
}

class _ComposeMessageDialogState extends State<ComposeMessageDialog> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await widget.onSend(message);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message envoyé'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Message à ${widget.receiverName}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        maxLength: 200,
        decoration: const InputDecoration(
          hintText: 'Écrivez votre message...',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _send(),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _send,
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Envoyer'),
        ),
      ],
    );
  }
}

/// Dialog pour afficher un message reçu avec option de réponse
class ReceivedMessageDialog extends StatefulWidget {
  final String senderName;
  final String message;
  final String timestamp;
  final Function(String message) onSend;
  final VoidCallback onClose;

  const ReceivedMessageDialog({
    super.key,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.onSend,
    required this.onClose,
  });

  @override
  State<ReceivedMessageDialog> createState() => _ReceivedMessageDialogState();
}

class _ReceivedMessageDialogState extends State<ReceivedMessageDialog> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await widget.onSend(message);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message envoyé'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.message, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Message de ${widget.senderName}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  widget.timestamp,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.done_all, size: 14, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Lu',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Répondre à ${widget.senderName}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: false,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Écrivez votre réponse...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              onSubmitted: (_) => _send(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onClose();
                },
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _isSending ? null : _send,
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 20),
          label: const Text('Envoyer'),
        ),
      ],
    );
  }
}
