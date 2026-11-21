import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

class _Room {
  final String id, name;
  final IconData icon;
  const _Room(this.id, this.name, this.icon);
}

List<_Room> roomsFor(AppUser me) {
  const bm = _Room('boys_members', 'شات مخدومي البنين', Icons.boy);
  const gm = _Room('girls_members', 'شات مخدومي البنات', Icons.girl);
  const bs = _Room('boys_servants', 'شات خدام البنين', Icons.groups);
  const gs = _Room('girls_servants', 'شات خدام البنات', Icons.groups_2);
  const all = _Room('servants_all', 'شات الخدام (بنين وبنات)', Icons.diversity_3);
  if (me.isGeneral) return [bm, gm, bs, gs, all];
  final sec = me.section == 'girls';
  if (me.isServant) return [sec ? gm : bm, sec ? gs : bs, all];
  return [sec ? gm : bm];
}

class ChatTab extends StatelessWidget {
  const ChatTab({super.key});
  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    final rooms = roomsFor(me);
    return Scaffold(
      appBar: gradAppBar('المحادثات'),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: rooms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(id: rooms[i].id, name: rooms[i].name))),
          child: AppCard(child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: AppColors.paleSky, child: Icon(rooms[i].icon, color: AppColors.royal)),
            const SizedBox(width: 12),
            Expanded(child: Text(rooms[i].name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            const Icon(Icons.chevron_left),
          ])),
        ),
      ),
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  final String id, name;
  const ChatRoomScreen({super.key, required this.id, required this.name});
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _ctl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool _canModerate(AppUser me) => me.isGeneral || (me.isServant && (widget.id == 'boys_members' || widget.id == 'girls_members'));

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _sending) return;
    final s = context.read<Session>();
    setState(() => _sending = true);
    try {
      await db.collection('chats/${widget.id}/messages').add({
        'senderId': s.appUser!.uid,
        'senderName': s.profile?.displayName ?? '',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _ctl.clear();
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return Scaffold(
      appBar: gradAppBar(widget.name),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('chats/${widget.id}/messages').orderBy('createdAt', descending: true).limit(150).snapshots(),
            builder: (c, snap) {
              if (snap.hasError) return EmptyState(AuthService.arabicError(snap.error!));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const EmptyState('لا توجد رسائل بعد. ابدأ المحادثة!', icon: Icons.chat_bubble_outline);
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final mine = d['senderId'] == me.uid;
                  final t = tsOf(d['createdAt']);
                  return GestureDetector(
                    onLongPress: _canModerate(me)
                        ? () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(title: const Text('حذف الرسالة؟'), actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
                              ]),
                            );
                            if (ok == true) await d.reference.delete();
                          }
                        : null,
                    child: _Bubble(senderId: d['senderId'] as String, name: (d.data()['senderName'] as String?) ?? '', text: d['text'] as String, time: t, mine: mine),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(children: [
              Expanded(child: TextField(controller: _ctl, minLines: 1, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(hintText: 'اكتب رسالة...', counterText: ''), onSubmitted: (_) => _send())),
              const SizedBox(width: 8),
              CircleAvatar(radius: 24, backgroundColor: AppColors.royal, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sending ? null : _send)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String senderId, name, text;
  final DateTime? time;
  final bool mine;
  const _Bubble({required this.senderId, required this.name, required this.text, required this.time, required this.mine});
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final bg = mine ? AppColors.royal : (dark ? const Color(0xFF16213F) : Colors.white);
    final fg = mine ? Colors.white : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: mine ? MainAxisAlignment.start : MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (mine) _avatar(),
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? '—' : name, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: mine ? AppColors.gold : AppColors.royal)),
              Text(text, style: TextStyle(color: fg, height: 1.5)),
              Align(alignment: Alignment.centerLeft, child: Text(time == null ? '...' : fmtTime(time!), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.black45))),
            ]),
          ),
        ),
        if (!mine) _avatar(),
      ]),
    );
  }

  Widget _avatar() => FutureBuilder<Profile?>(
        future: cachedProfile(senderId),
        builder: (c, p) => Avatar(photoUrl: p.data?.photoUrl, name: name, radius: 15),
      );
}
