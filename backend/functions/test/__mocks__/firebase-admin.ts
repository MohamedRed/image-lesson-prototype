let idSeq = 0;
const updates: Record<string, any> = {};
const docs: Record<string, any> = {
  'customers/u1': { fcmTokens: ['t1','t2','bad'] },
};

const firestoreImpl: any = () => ({
  doc: (path: string) => ({
    get: async () => ({ exists: docs[path] != null, data: () => docs[path] }),
    set: async (data: any) => { docs[path] = { ...(docs[path]||{}), ...data }; },
    update: async (data: any) => { docs[path] = { ...(docs[path]||{}), ...data }; updates[path] = data; },
  }),
  collection: (name: string) => ({
    add: async (data: any) => { const id = `${name}_${++idSeq}`; docs[`${name}/${id}`] = data; return { id }; },
    doc: (id?: string) => {
      const docId = id || `${name}_${++idSeq}`;
      const path = `${name}/${docId}`;
      return {
        id: docId,
        get: async () => ({ exists: docs[path] != null, data: () => docs[path] }),
        set: async (data: any, opts?: any) => { docs[path] = opts?.merge ? { ...(docs[path]||{}), ...data } : data; },
        update: async (data: any) => { docs[path] = { ...(docs[path]||{}), ...data }; updates[path] = data; },
        delete: async () => { delete docs[path]; }
      };
    }
  }),
  batch: () => {
    const ops: Array<() => void> = [];
    return {
      update: (ref: any, data: any) => { ops.push(() => { const path = ref.path || ref; docs[path] = { ...(docs[path]||{}), ...data }; updates[path] = data; }); },
      set: (ref: any, data: any, opts?: any) => { ops.push(() => { const path = ref.path || ref; docs[path] = opts?.merge ? { ...(docs[path]||{}), ...data } : data; }); },
      commit: async () => { ops.forEach(fn => fn()); }
    };
  },
  runTransaction: async (fn: any) => fn({ get: async () => ({ exists: false }), set: async () => {}, update: async () => {} })
});

firestoreImpl.FieldValue = {
  serverTimestamp: () => ({ toDate: () => new Date() }),
  increment: (n: number) => ({ __op: 'inc', n })
};
firestoreImpl.Timestamp = { fromDate: (d: Date) => d } as any;

const messagingImpl = () => ({
  sendEachForMulticast: async (msg: any) => ({
    successCount: msg.tokens.length - 1,
    failureCount: 1,
    responses: msg.tokens.map((t: string) => ({ success: t !== 'bad', error: t==='bad' ? { code: 'messaging/registration-token-not-registered' } : undefined }))
  }),
  send: async () => {}
});

export { firestoreImpl as firestore, messagingImpl as messaging };
export const ___seedDoc = (path: string, data: any) => { (docs as any)[path] = data; };
export default { firestore: firestoreImpl, messaging: messagingImpl, ___seedDoc } as any;


