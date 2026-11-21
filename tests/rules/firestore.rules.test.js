// اختبارات قواعد Firestore على المحاكي. تُشغَّل تلقائيًا من GitHub Actions (rules-test.yml).
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');

const ts = () => firebase.firestore.FieldValue.serverTimestamp();
const now = () => firebase.firestore.Timestamp.now();

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-khedmet-osra',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
afterAll(async () => { await env.cleanup(); });

const seedUser = (ctx, uid, role, section, status = 'active') =>
  ctx.firestore().doc(`users/${uid}`).set({ role, section, status, createdAt: now(), updatedAt: now() });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await seedUser(ctx, 'gen', 'general', 'all');
    await seedUser(ctx, 'bs', 'servant', 'boys');
    await seedUser(ctx, 'gs', 'servant', 'girls');
    await seedUser(ctx, 'bm', 'member', 'boys');
    await seedUser(ctx, 'bm2', 'member', 'boys');
    await seedUser(ctx, 'gm', 'member', 'girls');
    await seedUser(ctx, 'pend', 'member', 'boys', 'pending');
    await seedUser(ctx, 'susp', 'member', 'boys', 'suspended');
    await seedUser(ctx, 'sreq', 'member', 'boys', 'pending');
    const f = ctx.firestore();
    await f.doc('registrationRequests/pend').set({ uid: 'pend', displayName: 'Pending Boy', requestedRole: 'member', requestedSection: 'boys', status: 'pending', createdAt: now() });
    await f.doc('registrationRequests/sreq').set({ uid: 'sreq', displayName: 'Servant Req', requestedRole: 'servant', requestedSection: 'boys', status: 'pending', createdAt: now() });
    await f.doc('profiles/bm').set({ displayName: 'Boy One', section: 'boys', createdAt: now() });
    await f.doc('profiles/gm').set({ displayName: 'Girl One', section: 'girls', createdAt: now() });
    await f.doc('privateUsers/bm').set({ phone: '+201012345678' });
    await f.doc('privateUsers/bm2').set({ phone: '+201112345678' });
    await f.doc('points/p1').set({ uid: 'bm', section: 'boys', amount: 5, reason: 'x', category: 'manual', createdBy: 'bs', createdAt: now() });
    await f.doc('points/p2').set({ uid: 'bm2', section: 'boys', amount: 7, reason: 'x', category: 'manual', createdBy: 'bs', createdAt: now() });
    await f.doc('competitions/c1').set({ title: 'c', link: 'https://example.com', audience: 'boys', points: 10, startAt: now(), endAt: now(), status: 'active', createdBy: 'bs', createdAt: now() });
    await f.doc('competitions/c2').set({ title: 'c', link: 'https://example.com', audience: 'girls', points: 10, startAt: now(), endAt: now(), status: 'active', createdBy: 'gs', createdAt: now() });
    await f.doc('chats/boys_members/messages/m1').set({ senderId: 'bm', text: 'hi', createdAt: now() });
    await f.doc('chats/boys_servants/messages/m1').set({ senderId: 'bs', text: 'hi', createdAt: now() });
    await f.doc('notifications/n1').set({ uid: 'bm', title: 't', body: 'b', type: 'x', read: false, createdAt: now() });
    await f.doc('notifications/n2').set({ uid: 'bm2', title: 't', body: 'b', type: 'x', read: false, createdAt: now() });
    await f.doc('settings/app').set({ appName: 'x', boysEnabled: true, girlsEnabled: true, registrationEnabled: true, maintenanceMode: false });
  });
});

function registrationBatch(uid, { role = 'member', section = 'boys', reqRole = 'member', reqSection = 'boys' } = {}) {
  const f = db(uid);
  const b = f.batch();
  b.set(f.doc(`users/${uid}`), { role, section, status: 'pending', createdAt: ts(), updatedAt: ts() });
  b.set(f.doc(`profiles/${uid}`), { displayName: 'Mina Test', section, createdAt: ts() });
  b.set(f.doc(`privateUsers/${uid}`), { phone: '+201000000001', birthDate: now() });
  b.set(f.doc(`registrationRequests/${uid}`), { uid, displayName: 'Mina Test', requestedRole: reqRole, requestedSection: reqSection, status: 'pending', createdAt: ts() });
  return b;
}

describe('التسجيل', () => {
  test('مخدوم جديد يسجل كـ member/pending', async () => { await assertSucceeds(registrationBatch('new1').commit()); });
  test('طلب خادم = member + requestedRole=servant', async () => { await assertSucceeds(registrationBatch('new2', { reqRole: 'servant' }).commit()); });
  test('طلب عام بقسم all', async () => { await assertSucceeds(registrationBatch('new3', { section: 'all', reqRole: 'general', reqSection: 'all' }).commit()); });
  test('ممنوع إنشاء حساب general مباشرة', async () => { await assertFails(registrationBatch('hack1', { role: 'general', section: 'all', reqRole: 'general', reqSection: 'all' }).commit()); });
  test('ممنوع إنشاء حساب servant مباشرة', async () => { await assertFails(registrationBatch('hack2', { role: 'servant', reqRole: 'servant' }).commit()); });
  test('ممنوع إنشاء حساب active مباشرة', async () => {
    await assertFails(db('hack3').doc('users/hack3').set({ role: 'member', section: 'boys', status: 'active', createdAt: ts() }));
  });
  test('ممنوع مخدوم بقسم all', async () => { await assertFails(registrationBatch('hack4', { section: 'all', reqSection: 'all' }).commit()); });
  test('ممنوع إنشاء حساب بـ uid غيره', async () => {
    await assertFails(db('attacker').doc('users/victim').set({ role: 'member', section: 'boys', status: 'pending', createdAt: ts() }));
  });
  test('غير مسجل لا يكتب', async () => {
    await assertFails(anon().doc('users/x').set({ role: 'member', section: 'boys', status: 'pending', createdAt: ts() }));
  });
  test('التسجيل يتوقف عند إغلاقه', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await ctx.firestore().doc('settings/app').set({ registrationEnabled: false }); });
    await assertFails(registrationBatch('closed1').commit());
  });
});

describe('منع تغيير الدور/القسم/الحالة', () => {
  test('مخدوم لا يغير دوره', async () => { await assertFails(db('bm').doc('users/bm').update({ role: 'general' })); });
  test('مخدوم لا يغير قسمه', async () => { await assertFails(db('bm').doc('users/bm').update({ section: 'girls' })); });
  test('معلّق لا يفعّل نفسه', async () => { await assertFails(db('pend').doc('users/pend').update({ status: 'active' })); });
  test('خادم لا يرقي نفسه', async () => { await assertFails(db('bs').doc('users/bs').update({ role: 'general', section: 'all' })); });
  test('خادم يقبل طلب خادم في قسمه (يصبح servant)', async () => { await assertSucceeds(db('bs').doc('users/sreq').update({ role: 'servant', status: 'active', updatedAt: ts() })); });
  test('خادم لا يمنح دور general', async () => { await assertFails(db('bs').doc('users/sreq').update({ role: 'general', status: 'active', updatedAt: ts() })); });
  test('خادم لا يرقي طلب مخدوم عادي إلى خادم', async () => { await assertFails(db('bs').doc('users/pend').update({ role: 'servant', status: 'active', updatedAt: ts() })); });
  test('خادم لا يرقي مخدومًا', async () => { await assertFails(db('bs').doc('users/pend').update({ role: 'servant', status: 'active', updatedAt: ts() })); });
  test('خادم بنين لا يراجع بنات', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await seedUser(ctx, 'gpend', 'member', 'girls', 'pending');
      await ctx.firestore().doc('registrationRequests/gpend').set({ uid: 'gpend', displayName: 'G Pend', requestedRole: 'member', requestedSection: 'girls', status: 'pending', createdAt: now() });
    });
    await assertFails(db('bs').doc('users/gpend').update({ status: 'active', updatedAt: ts() }));
  });
  test('خادم بنين يقبل مخدوم بنين', async () => { await assertSucceeds(db('bs').doc('users/pend').update({ status: 'active', updatedAt: ts() })); });
  test('العام يرقي طلب خادم', async () => { await assertSucceeds(db('gen').doc('users/sreq').update({ role: 'servant', status: 'active', updatedAt: ts() })); });
  test('خادم يقرأ طلبات قسمه ولا يقرأ طلبات العام', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await ctx.firestore().doc('registrationRequests/greq').set({ uid: 'greq', displayName: 'Gen Req', requestedRole: 'general', requestedSection: 'all', status: 'pending', createdAt: now() }); });
    await assertSucceeds(db('bs').doc('registrationRequests/sreq').get());
    await assertSucceeds(db('bs').doc('registrationRequests/pend').get());
    await assertFails(db('bs').doc('registrationRequests/greq').get());
  });
  test('استعلام طلبات القسم مسموح', async () => {
    await assertSucceeds(db('bs').collection('registrationRequests').where('status', '==', 'pending').where('requestedSection', '==', 'boys').get());
  });
});

describe('الخصوصية', () => {
  test('مخدوم يقرأ بياناته الخاصة فقط', async () => {
    await assertSucceeds(db('bm').doc('privateUsers/bm').get());
    await assertFails(db('bm').doc('privateUsers/bm2').get());
  });
  test('الخادم لا يقرأ الهواتف', async () => { await assertFails(db('bs').doc('privateUsers/bm').get()); });
  test('العام يقرأ الخاص', async () => { await assertSucceeds(db('gen').doc('privateUsers/bm').get()); });
  test('مخدوم لا يقرأ users غيره', async () => { await assertFails(db('bm').doc('users/bm2').get()); });
  test('profile زميل القسم نعم، قسم آخر لا', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await ctx.firestore().doc('profiles/bm2').set({ displayName: 'Boy Two', section: 'boys', createdAt: now() }); });
    await assertSucceeds(db('bm').doc('profiles/bm2').get());
    await assertFails(db('bm').doc('profiles/gm').get());
  });
  test('لا تغيير للهاتف', async () => { await assertFails(db('bm').doc('privateUsers/bm').update({ phone: '+201999999999' })); });
  test('تعديل الاسم فقط في profile', async () => {
    await assertSucceeds(db('bm').doc('profiles/bm').update({ displayName: 'Boy Renamed' }));
    await assertFails(db('bm').doc('profiles/bm').update({ section: 'girls' }));
  });
  test('لا تعديل profile غيره', async () => { await assertFails(db('bm2').doc('profiles/bm').update({ displayName: 'Hacked' })); });
});

const point = (over = {}) => ({ uid: 'bm', section: 'boys', amount: 5, reason: 'حضور', category: 'mass', createdBy: 'bs', createdAt: ts(), ...over });
describe('النقاط', () => {
  test('مخدوم يرى نقاطه فقط', async () => {
    await assertSucceeds(db('bm').collection('points').where('uid', '==', 'bm').get());
    await assertFails(db('bm').doc('points/p2').get());
    await assertFails(db('bm').collection('points').get());
  });
  test('مخدوم لا يضيف', async () => { await assertFails(db('bm').collection('points').add(point({ createdBy: 'bm' }))); });
  test('خادم بنين يضيف لبنين', async () => { await assertSucceeds(db('bs').collection('points').add(point())); });
  test('خادم بنين لا يضيف لبنت', async () => { await assertFails(db('bs').collection('points').add(point({ uid: 'gm', section: 'girls' }))); });
  test('خادمة بنات لا تضيف لولد', async () => { await assertFails(db('gs').collection('points').add(point({ createdBy: 'gs' }))); });
  test('العام يضيف لأي قسم', async () => { await assertSucceeds(db('gen').collection('points').add(point({ createdBy: 'gen' }))); });
  test('لا تزوير createdBy', async () => { await assertFails(db('bs').collection('points').add(point({ createdBy: 'gen' }))); });
  test('مقدار/سبب غير صالح', async () => {
    await assertFails(db('bs').collection('points').add(point({ amount: -5 })));
    await assertFails(db('bs').collection('points').add(point({ amount: 100000 })));
    await assertFails(db('bs').collection('points').add(point({ reason: '' })));
  });
  test('التونية للبنين فقط', async () => {
    await assertSucceeds(db('bs').collection('points').add(point({ category: 'tonia' })));
    await assertFails(db('gs').collection('points').add(point({ uid: 'gm', section: 'girls', category: 'tonia', createdBy: 'gs' })));
  });
  test('لا تعديل/حذف من الخادم', async () => {
    await assertFails(db('bs').doc('points/p1').update({ amount: 999 }));
    await assertFails(db('bs').doc('points/p1').delete());
    await assertSucceeds(db('gen').doc('points/p1').update({ amount: 6 }));
  });
  test('لا نقاط لمعلّق', async () => { await assertFails(db('bs').collection('points').add(point({ uid: 'pend' }))); });
});

const att = (over = {}) => ({ uid: 'bm', section: 'boys', eventId: 'mass-1', type: 'mass', date: now(), createdBy: 'bs', createdAt: ts(), ...over });
describe('الحضور', () => {
  test('خادم يسجل حضور قسمه', async () => { await assertSucceeds(db('bs').doc('attendance/mass-1_bm').set(att())); });
  test('منع التكرار', async () => {
    await assertSucceeds(db('bs').doc('attendance/mass-1_bm').set(att()));
    await assertFails(db('bs').doc('attendance/mass-1_bm').set(att()));
  });
  test('المعرّف يطابق الفعالية والمخدوم', async () => { await assertFails(db('bs').doc('attendance/random').set(att())); });
  test('مخدوم لا يسجل حضورًا', async () => { await assertFails(db('bm').doc('attendance/mass-1_bm').set(att({ createdBy: 'bm' }))); });
  test('خادم بنين لا يسجل لبنت', async () => { await assertFails(db('bs').doc('attendance/mass-1_gm').set(att({ uid: 'gm', section: 'girls' }))); });
});

describe('المسابقات', () => {
  const comp = (over = {}) => ({ title: 'مسابقة', description: 'd', link: 'https://example.com/q', audience: 'boys', points: 10, startAt: now(), endAt: now(), status: 'active', createdBy: 'bs', createdAt: ts(), ...over });
  test('خادم ينشئ لقسمه', async () => { await assertSucceeds(db('bs').collection('competitions').add(comp())); });
  test('لا لقسم آخر ولا للجميع', async () => {
    await assertFails(db('bs').collection('competitions').add(comp({ audience: 'girls' })));
    await assertFails(db('bs').collection('competitions').add(comp({ audience: 'all' })));
  });
  test('العام ينشئ للجميع', async () => { await assertSucceeds(db('gen').collection('competitions').add(comp({ audience: 'all', createdBy: 'gen' }))); });
  test('رابط غير http مرفوض', async () => { await assertFails(db('bs').collection('competitions').add(comp({ link: 'javascript:alert(1)' }))); });
  test('مخدوم لا ينشئ', async () => { await assertFails(db('bm').collection('competitions').add(comp({ createdBy: 'bm' }))); });
  test('مخدوم يرى مسابقات قسمه فقط', async () => {
    await assertSucceeds(db('bm').doc('competitions/c1').get());
    await assertFails(db('bm').doc('competitions/c2').get());
  });
  const sub = (over = {}) => ({ competitionId: 'c1', uid: 'bm', section: 'boys', answerEvidence: 'الحل', status: 'pending', createdAt: ts(), ...over });
  test('مشاركة واحدة لكل مخدوم', async () => {
    await assertSucceeds(db('bm').doc('competitionSubmissions/c1_bm').set(sub()));
    await assertFails(db('bm').doc('competitionSubmissions/c1_bm').set(sub()));
  });
  test('لا انتحال ولا حالة approved', async () => {
    await assertFails(db('bm').doc('competitionSubmissions/c1_bm2').set(sub({ uid: 'bm2' })));
    await assertFails(db('bm').doc('competitionSubmissions/c1_bm').set(sub({ status: 'approved' })));
  });
  test('لا مشاركة في مسابقة قسم آخر', async () => { await assertFails(db('bm').doc('competitionSubmissions/c2_bm').set(sub({ competitionId: 'c2' }))); });
  test('المخدوم لا يراجع مشاركته', async () => {
    await assertSucceeds(db('bm').doc('competitionSubmissions/c1_bm').set(sub()));
    await assertFails(db('bm').doc('competitionSubmissions/c1_bm').update({ status: 'approved', reviewedBy: 'bm', reviewedAt: ts() }));
  });
  test('الموافقة + النقاط مرة واحدة فقط', async () => {
    await assertSucceeds(db('bm').doc('competitionSubmissions/c1_bm').set(sub()));
    const f = db('bs');
    const b = f.batch();
    b.update(f.doc('competitionSubmissions/c1_bm'), { status: 'approved', reviewedBy: 'bs', reviewedAt: ts() });
    b.set(f.doc('points/comp_c1_bm'), point({ amount: 10, category: 'competition', competitionId: 'c1', reason: 'مسابقة' }));
    await assertSucceeds(b.commit());
    const b2 = f.batch();
    b2.update(f.doc('competitionSubmissions/c1_bm'), { status: 'approved', reviewedBy: 'bs', reviewedAt: ts() });
    await assertFails(b2.commit());
    await assertFails(f.doc('points/comp_c1_bm').set(point({ amount: 10, category: 'competition', competitionId: 'c1', reason: 'مسابقة' })));
  });
  test('نقاط مسابقة بلا مشاركة معتمدة مرفوضة', async () => {
    await assertFails(db('bs').doc('points/comp_c1_bm').set(point({ amount: 10, category: 'competition', competitionId: 'c1', reason: 'مسابقة' })));
  });
});

describe('الأنشطة', () => {
  const act = (over = {}) => ({ title: 'رحلة', audience: 'boys', date: now(), status: 'active', createdBy: 'bs', createdAt: ts(), ...over });
  test('خادم ينشئ لقسمه فقط', async () => {
    await assertSucceeds(db('bs').collection('activities').add(act()));
    await assertFails(db('bs').collection('activities').add(act({ audience: 'girls' })));
    await assertFails(db('bs').collection('activities').add(act({ audience: 'all' })));
  });
  test('مخدوم لا ينشئ', async () => { await assertFails(db('bm').collection('activities').add(act({ createdBy: 'bm' }))); });
  test('العام ينشئ للجميع', async () => { await assertSucceeds(db('gen').collection('activities').add(act({ audience: 'all', createdBy: 'gen' }))); });
});

const msg = (uid, text = 'مرحبا') => ({ senderId: uid, text, createdAt: ts() });
describe('الشات', () => {
  test('مخدوم بنين يكتب في شات بنين فقط', async () => {
    await assertSucceeds(db('bm').collection('chats/boys_members/messages').add(msg('bm')));
    await assertFails(db('bm').collection('chats/girls_members/messages').add(msg('bm')));
    await assertFails(db('bm').collection('chats/boys_servants/messages').add(msg('bm')));
    await assertFails(db('bm').collection('chats/servants_all/messages').add(msg('bm')));
  });
  test('مخدوم لا يقرأ غرف الخدام', async () => {
    await assertFails(db('bm').doc('chats/boys_servants/messages/m1').get());
    await assertSucceeds(db('bm').doc('chats/boys_members/messages/m1').get());
  });
  test('قسم لا يدخل غرفة القسم الآخر', async () => {
    await assertFails(db('gm').doc('chats/boys_members/messages/m1').get());
    await assertFails(db('gs').doc('chats/boys_servants/messages/m1').get());
  });
  test('الغرفة المشتركة للخدام', async () => {
    await assertSucceeds(db('bs').collection('chats/servants_all/messages').add(msg('bs')));
    await assertSucceeds(db('gs').collection('chats/servants_all/messages').add(msg('gs')));
  });
  test('لا انتحال مرسل', async () => { await assertFails(db('bm').collection('chats/boys_members/messages').add(msg('bm2'))); });
  test('معلّق/موقوف/غير مسجل لا يدخلون', async () => {
    await assertFails(db('pend').doc('chats/boys_members/messages/m1').get());
    await assertFails(db('susp').doc('chats/boys_members/messages/m1').get());
    await assertFails(anon().doc('chats/boys_members/messages/m1').get());
  });
  test('العام يدخل كل الغرف', async () => {
    await assertSucceeds(db('gen').doc('chats/girls_members/messages/x').get());
    await assertSucceeds(db('gen').collection('chats/boys_servants/messages').add(msg('gen')));
  });
  test('لا تعديل رسائل، والخادم يحذف في غرفة قسمه', async () => {
    await assertFails(db('bm').doc('chats/boys_members/messages/m1').update({ text: 'x' }));
    await assertSucceeds(db('bs').doc('chats/boys_members/messages/m1').delete());
  });
  test('غرفة غير معروفة مرفوضة', async () => { await assertFails(db('gen').collection('chats/hack/messages').add(msg('gen'))); });
});

describe('الإشعارات', () => {
  const notif = (uid, over = {}) => ({ uid, title: 'عنوان', body: 'نص', type: 'account', relatedId: '', read: false, createdAt: ts(), ...over });
  test('مخدوم يقرأ إشعاراته فقط', async () => {
    await assertSucceeds(db('bm').doc('notifications/n1').get());
    await assertFails(db('bm').doc('notifications/n2').get());
  });
  test('مخدوم لا ينشئ إشعارات', async () => { await assertFails(db('bm').collection('notifications').add(notif('bm2'))); });
  test('خادم يرسل لقسمه لا لقسم آخر', async () => {
    await assertSucceeds(db('bs').collection('notifications').add(notif('bm')));
    await assertFails(db('bs').collection('notifications').add(notif('gm')));
  });
  test('إعلان جماعي لقسمه فقط', async () => {
    await assertSucceeds(db('bs').collection('notifications').add(notif('boys')));
    await assertFails(db('bs').collection('notifications').add(notif('girls')));
    await assertFails(db('bs').collection('notifications').add(notif('all')));
  });
  test('تعليم كمقروء فقط', async () => {
    await assertSucceeds(db('bm').doc('notifications/n1').update({ read: true }));
    await assertFails(db('bm').doc('notifications/n1').update({ title: 'x' }));
  });
  test('المعلّق يقرأ إشعار حسابه', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await ctx.firestore().doc('notifications/np').set({ uid: 'pend', title: 't', body: 'b', type: 'account', read: false, createdAt: now() }); });
    await assertSucceeds(db('pend').doc('notifications/np').get());
  });
});

describe('الإعدادات', () => {
  test('أي مسجل يقرأ، والعام فقط يكتب', async () => {
    await assertSucceeds(db('bm').doc('settings/app').get());
    await assertFails(anon().doc('settings/app').get());
    await assertFails(db('bs').doc('settings/app').update({ maintenanceMode: true }));
    await assertSucceeds(db('gen').doc('settings/app').set({ appName: 'x', boysEnabled: true, girlsEnabled: true, registrationEnabled: true, maintenanceMode: true }));
  });
  test('مستند آخر في settings مرفوض', async () => { await assertFails(db('gen').doc('settings/other').set({ appName: 'x' })); });
});

test('مجموعة غير معرّفة مرفوضة', async () => {
  await assertFails(db('gen').doc('whatever/x').set({ a: 1 }));
  await assertFails(db('gen').doc('whatever/x').get());
});

// ───────── أول حساب عام (Bootstrap) ─────────
function bootBatch(uid) {
  const f = db(uid); const b = f.batch();
  b.set(f.doc(`users/${uid}`), { role: 'general', section: 'all', status: 'active', createdAt: ts(), updatedAt: ts() });
  b.set(f.doc(`profiles/${uid}`), { displayName: 'Admin One', section: 'all', createdAt: ts() });
  b.set(f.doc(`privateUsers/${uid}`), { phone: '+201000000009' });
  b.set(f.doc(`registrationRequests/${uid}`), { uid, displayName: 'Admin One', requestedRole: 'general', requestedSection: 'all', status: 'approved', createdAt: ts() });
  b.set(f.doc('settings/app'), { appName: 'x', boysEnabled: true, girlsEnabled: true, registrationEnabled: true, maintenanceMode: false });
  return b;
}
describe('أول حساب عام', () => {
  test('ممنوع بعد وجود الإعدادات', async () => { await assertFails(bootBatch('boot1').commit()); });
  test('مسموح مرة واحدة عند عدم وجود الإعدادات ثم يُغلق', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await ctx.firestore().doc('settings/app').delete(); });
    await assertSucceeds(bootBatch('boot1').commit());
    await assertFails(bootBatch('boot2').commit());
  });
  test('مخدوم لا ينشئ settings/app', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await ctx.firestore().doc('settings/app').delete(); });
    await assertFails(db('bm').doc('settings/app').set({ appName: 'x' }));
  });
  test('حساب active بدور general بدون settings في نفس الدفعة مرفوض', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await ctx.firestore().doc('settings/app').delete(); });
    const f = db('boot3'); const b = f.batch();
    b.set(f.doc('users/boot3'), { role: 'general', section: 'all', status: 'active', createdAt: ts() });
    b.set(f.doc('registrationRequests/boot3'), { uid: 'boot3', displayName: 'Admin', requestedRole: 'general', requestedSection: 'all', status: 'approved', createdAt: ts() });
    await assertFails(b.commit());
  });
});

// ───────── تأكيد الاشتراك في الأنشطة ─────────
describe('اشتراك الأنشطة', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('activities/a1').set({ title: 'رحلة', audience: 'boys', date: now(), status: 'active', createdBy: 'bs', createdAt: now() });
      await ctx.firestore().doc('activities/a2').set({ title: 'رحلة', audience: 'girls', date: now(), status: 'active', createdBy: 'gs', createdAt: now() });
    });
  });
  const reg = (uid, sec) => ({ uid, section: sec, createdAt: ts() });
  test('مخدوم يشترك في نشاط قسمه مرة واحدة', async () => {
    await assertSucceeds(db('bm').doc('activities/a1/registrations/bm').set(reg('bm', 'boys')));
    await assertFails(db('bm').doc('activities/a1/registrations/bm').set(reg('bm', 'boys')));
  });
  test('لا اشتراك في نشاط قسم آخر ولا باسم غيره', async () => {
    await assertFails(db('bm').doc('activities/a2/registrations/bm').set(reg('bm', 'boys')));
    await assertFails(db('bm').doc('activities/a1/registrations/bm2').set(reg('bm2', 'boys')));
  });
  test('الخادم يرى المشتركين في قسمه فقط', async () => {
    await assertSucceeds(db('bs').collection('activities/a1/registrations').get());
    await assertFails(db('bs').collection('activities/a2/registrations').get());
  });
  test('مخدوم لا يرى اشتراك غيره', async () => {
    await assertFails(db('bm2').collection('activities/a1/registrations').get());
  });
  test('انتهاء آخر موعد يمنع الاشتراك', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('activities/a3').set({ title: 't', audience: 'boys', date: now(), status: 'active', registrationDeadline: firebase.firestore.Timestamp.fromMillis(Date.now() - 86400000), createdBy: 'bs', createdAt: now() });
    });
    await assertFails(db('bm').doc('activities/a3/registrations/bm').set(reg('bm', 'boys')));
  });
});

// ───────── الآيات ─────────
describe('الآيات', () => {
  const verse = (over = {}) => ({ text: 'نص', reference: 'مرجع', category: 'تشجيع', active: true, createdBy: 'gen', createdAt: ts(), ...over });
  test('العام يضيف والمخدوم يقرأ فقط', async () => {
    await assertSucceeds(db('gen').collection('verses').add(verse()));
    await assertFails(db('bm').collection('verses').add(verse({ createdBy: 'bm' })));
    await assertSucceeds(db('bm').collection('verses').get());
    await assertFails(db('bs').collection('verses').add(verse({ createdBy: 'bs' })));
  });
});

test('رسالة الشات بـ senderName', async () => {
  await assertSucceeds(db('bm').collection('chats/boys_members/messages').add({ senderId: 'bm', senderName: 'مينا', text: 'x', createdAt: ts() }));
});
