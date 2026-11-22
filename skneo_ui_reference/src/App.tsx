import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';

type Glyph = 'home' | 'mail' | 'plus' | 'bell' | 'user' | 'heart' | 'comment' | 'bookmark' | 'back' | 'arrow' | 'more' | 'close' | 'check' | 'alert' | 'image' | 'play' | 'mountain' | 'moon' | 'sun' | 'edit' | 'trash';
function Icon({ name, className = '' }: { name: Glyph; className?: string }) {
  const paths: Record<Glyph, ReactNode> = {
    home: <><path d="m3 10 9-7 9 7v10H3Z" /><path d="M9 20v-7h6v7" /></>,
    mail: <><rect x="3" y="5" width="18" height="14" rx="3" /><path d="m3 7 9 6 9-6" /></>,
    plus: <path d="M12 4v16M4 12h16" />,
    bell: <><path d="M5 17h14l-2-4V9a5 5 0 0 0-10 0v4Z" /><path d="M10 21h4" /></>,
    user: <><circle cx="12" cy="7" r="4" /><path d="M4 21a8 8 0 0 1 16 0" /></>,
    heart: <path d="M20 5c-3-3-7-1-8 1-1-2-5-4-8-1-4 4 1 9 8 15 7-6 12-11 8-15Z" />,
    comment: <path d="M21 11a9 9 0 0 1-9 9H4l1-5a9 9 0 1 1 16-4Z" />,
    bookmark: <path d="M6 3h12v18l-6-4-6 4Z" />,
    back: <path d="m15 5-7 7 7 7" />, arrow: <path d="m9 5 7 7-7 7" />,
    more: <><circle cx="5" cy="12" r="1" /><circle cx="12" cy="12" r="1" /><circle cx="19" cy="12" r="1" /></>,
    close: <path d="m6 6 12 12M6 18 18 6" />, check: <path d="m5 12 5 5L20 7" />,
    alert: <><circle cx="12" cy="12" r="9" /><path d="M12 7v6m0 3v1" /></>,
    image: <><rect x="3" y="3" width="18" height="18" rx="4" /><circle cx="8" cy="8" r="1" /><path d="m3 17 6-6 4 4 3-3 5 5" /></>,
    play: <path d="m9 5 11 7-11 7Z" />,
    mountain: <><path d="m2 20 7-13 4 7 3-5 6 11Z" /><path d="m6 13 3 2 2-2" /></>,
    moon: <path d="M20 15A9 9 0 0 1 9 4a9 9 0 1 0 11 11Z" />,
    sun: <><circle cx="12" cy="12" r="4" /><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l2 2m10 10 2 2M5 19l2-2M17 7l2-2" /></>,
    edit: <><path d="m14 4 6 6M4 20l2-7L16 3l5 5-10 10Z" /></>,
    trash: <><path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7m4-7v7" /></>,
  };
  return <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" className={`h-6 w-6 shrink-0 ${className}`}>{paths[name]}</svg>;
}

const button = 'min-h-11 rounded-xl px-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-neutral-500 transition-colors';
const muted = 'text-[var(--muted)]';
const solid = `${button} bg-[var(--ink)] text-[var(--paper)] font-semibold text-sm disabled:bg-[var(--soft)] disabled:text-[var(--muted)] disabled:cursor-not-allowed`;
const input = `${button} w-full min-w-0 border border-[var(--line)] bg-[var(--paper)] text-base`;
const snow = 'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?auto=format&fit=crop&w=800&q=85';
const ski = 'https://images.unsplash.com/photo-1551524164-687a55dd1126?auto=format&fit=crop&w=800&q=85';
const regions = ['北京', '河北', '黑龙江', '吉林', '辽宁'];
const kinds = ['约滑', '约拍', '约饭', '约装备'];
const statuses = ['招募中', '已满员', '已结束', '已取消'];
type Post = { id: number; name: string; region: string; title: string; text: string; images: string[]; likes: number; time: string; own?: boolean; video?: boolean };
const posts: Post[] = [
  { id: 1, name: '山里的阿屿', region: '河北 · 万龙滑雪场', title: '山顶见，把这个冬天交给雪。', text: '赶上了清晨第一趟缆车。\n没有比阳光、粉雪和一群雪友更好的周末了。', images: [snow, ski], likes: 128, time: '3 小时前' },
  { id: 2, name: '小满在滑雪', region: '吉林 · 松花湖滑雪场', title: '今天，终于学会了换刃。', text: '摔了很多次，也笑了很多次。原来进步，是不再害怕下一次。', images: [], likes: 36, time: '5 小时前' },
  { id: 3, name: '北野', region: '北京 · 南山滑雪场', title: '留住收板前的最后一趟。', text: '山风和日落，是今天最好的奖励。', images: [ski], likes: 64, time: '8 小时前', video: true },
  { id: 4, name: '林间一条鱼', region: '河北 · 万龙滑雪场', title: '属于这个雪季的小小记录', text: '在雪上，时间好像会慢一点。', images: [ski], likes: 12, time: '昨天', own: true },
];
const events = [
  { id: 11, title: '周末万龙，一起追一场粉雪', region: '河北', resort: '万龙滑雪场', kind: '约滑', status: 0, count: 3, max: 10 },
  { id: 12, title: '日落时分，记录你的雪上瞬间', region: '北京', resort: '南山滑雪场', kind: '约拍', status: 1, count: 6, max: 6 },
  { id: 13, title: '滑完这一趟，一起吃顿热的', region: '吉林', resort: '松花湖滑雪场', kind: '约饭', status: 2, count: 8, max: 0 },
  { id: 14, title: '聊聊这个雪季的装备选择', region: '黑龙江', resort: '亚布力滑雪场', kind: '约装备', status: 3, count: 2, max: 10 },
];
const comments = [
  { id: 1, name: '小满在滑雪', text: '这个雪况太棒了，下次也要赶早场。', time: '1 小时前', likes: 8, reply: false, own: false },
  { id: 2, name: '山里的阿屿', text: '回复 小满在滑雪：早场的阳光真的值得！', time: '45 分钟前', likes: 3, reply: true, own: false },
  { id: 3, name: '林间一条鱼', text: '已经开始期待下一个雪天了。', time: '20 分钟前', likes: 2, reply: false, own: true },
];
const notices = ['你的活动有新的报名', '你已成功报名活动', '你的举报已处理'];
const reports = [
  { title: '雪场交流帖', reason: '垃圾广告', note: '评论中包含重复推广信息。', excerpt: '添加联系方式获取优惠……' },
  { title: '这条回复包含不当言论', reason: '不友善内容', note: '请核查评论内容。', excerpt: '针对其他雪友的人身攻击。' },
  { title: '雪友用户资料', reason: '违规资料', note: '头像与签名可能包含广告。', excerpt: '用户昵称与个性签名' },
];
function Photo({ src, alt = '雪场风景', className = '', mode = '正常' }: { src: string; alt?: string; className?: string; mode?: string }) {
  const [failed, setFailed] = useState(false);
  const [loaded, setLoaded] = useState(false);
  if (failed || mode === '加载失败') return <div className={`flex items-center justify-center bg-[var(--soft)] ${className}`}><svg role="img" aria-label="图片加载失败" viewBox="0 0 220 130" className="h-32 w-full text-[var(--muted)]"><path d="m30 85 40-45 25 30 30-40 65 55" stroke="currentColor" fill="none" /><text x="110" y="115" textAnchor="middle" fontSize="14" fill="currentColor">图片暂时无法加载</text></svg></div>;
  if (mode === '加载中') return <div role="status" aria-label="图片加载中" className={`bg-[var(--soft)] motion-safe:animate-pulse ${className}`} />;
  return <div className={`relative overflow-hidden bg-[var(--soft)] ${className}`}>{!loaded && <span className={`absolute inset-0 flex items-center justify-center text-sm ${muted}`}>图片加载中</span>}<img src={src} alt={alt} onLoad={() => setLoaded(true)} onError={() => setFailed(true)} className="relative h-full w-full object-cover" /></div>;
}
function Avatar({ small = false }: { small?: boolean }) {
  return <span className={`flex shrink-0 items-center justify-center rounded-full border border-[var(--line)] bg-[var(--soft)] ${muted} ${small ? 'h-8 w-8' : 'h-11 w-11'}`}><Icon name="user" className={small ? 'h-4 w-4' : 'h-5 w-5'} /></span>;
}
function Chip({ status }: { status: number }) {
  return <span className={`inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-xs ${['bg-[var(--ink)] text-[var(--paper)]', 'border border-[var(--muted)]', `bg-[var(--soft)] ${muted}`, `border border-dashed border-[var(--muted)] ${muted}`][status]}`}><span className="h-1 w-1 rounded-full bg-current" />{statuses[status]}</span>;
}
function Tabs({ items, value, onChange }: { items: string[]; value: string; onChange: (v: string) => void }) {
  return <div role="tablist" className="flex border-b border-[var(--line)]">{items.map(t => <button key={t} role="tab" aria-selected={value === t} onClick={() => onChange(t)} className={`${button} flex-1 rounded-none border-b-2 px-1 text-sm font-semibold ${value === t ? 'border-[var(--ink)]' : `border-transparent ${muted}`}`}>{t}</button>)}</div>;
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return <label className="block text-sm font-medium">{label}<span className="mt-2 block">{children}</span></label>;
}
function Sheet({ title, close, children }: { title: string; close: () => void; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const dismiss = useRef(close);
  dismiss.current = close;
  useEffect(() => {
    const previous = document.activeElement as HTMLElement;
    const root = ref.current!;
    root.querySelector<HTMLElement>('button,input,textarea,select')?.focus();
    function key(e: KeyboardEvent) {
      if (e.key === 'Escape') dismiss.current();
      if (e.key !== 'Tab') return;
      const items = Array.from(root.querySelectorAll<HTMLElement>('button:not(:disabled),input,textarea,select,[tabindex="0"]'));
      if (e.shiftKey && document.activeElement === items[0]) { e.preventDefault(); items[items.length - 1]?.focus(); }
      if (!e.shiftKey && document.activeElement === items[items.length - 1]) { e.preventDefault(); items[0]?.focus(); }
    }
    document.addEventListener('keydown', key);
    return () => { document.removeEventListener('keydown', key); previous?.focus(); };
  }, []);
  return <div className="absolute inset-0 z-40 flex items-end bg-black/35" onClick={close}><div ref={ref} role="dialog" aria-modal="true" aria-labelledby="sheet-title" onClick={e => e.stopPropagation()} className="max-h-[90%] w-full overflow-y-auto rounded-t-[28px] bg-[var(--paper)] p-5 pb-8"><div className="mx-auto mb-3 h-1 w-9 rounded-full bg-[var(--line)]" /><div className="mb-5 flex items-center justify-between"><h2 id="sheet-title" className="text-lg font-semibold">{title}</h2><button aria-label="关闭弹层" onClick={close} className={button}><Icon name="close" /></button></div>{children}</div></div>;
}
function StateView({ state, page, retry, login }: { state: string; page: string; retry: () => void; login: () => void }) {
  if (state === '加载中') return <div role="status" aria-label="加载中" className="space-y-8 p-5 motion-safe:animate-pulse">{[1, 2].map(n => <div key={n} className="space-y-3"><div className="h-11 w-11 rounded-full bg-[var(--soft)]" /><div className="ml-14 h-3 w-1/2 rounded bg-[var(--soft)]" /><div className="ml-14 h-40 rounded-2xl bg-[var(--soft)]" /></div>)}</div>;
  const empty = page.includes('评论') ? '还没有评论' : page === '通知' ? '暂时没有通知' : page.includes('收藏') ? '还没有收藏' : page.includes('活动') || page === '约约约列表' ? '还没有活动' : '还没有动态';
  return <div className="flex min-h-[380px] flex-col items-center justify-center gap-4 px-6 text-center"><Icon name={state === '加载失败' ? 'alert' : state === '未登录' ? 'user' : 'mountain'} className={`h-9 w-9 ${muted}`} /><h3 className="text-lg font-semibold">{state === '加载失败' ? '暂时没有加载出来' : state === '未登录' ? '登录，记录你的雪上日常' : empty}</h3><p className={`text-sm leading-6 ${muted}`}>{state === '加载失败' ? '请检查网络后再试一次。' : state === '未登录' ? '与雪友分享，也为下一次相约出发。' : '留一点空白，等下一段雪上的故事。'}</p>{state === '加载失败' && <button className={solid} onClick={retry}>重新加载</button>}{state === '未登录' && <div className="flex gap-3"><button className={solid} onClick={login}>登录 / 注册</button></div>}</div>;
}

export type SkneoUIProps = {
  initialPage?: string;
  appearance?: 'light' | 'dark' | 'system';
  initialState?: string;
  isAdmin?: boolean;
  authorView?: boolean;
  activityId?: number;
  registrationState?: string;
};

export default function App({
  initialPage = '首页',
  appearance = 'system',
  initialState = '正常',
  isAdmin = false,
  authorView = false,
  activityId = 11,
  registrationState = '可报名',
}: SkneoUIProps = {}) {
  const [systemDark, setSystemDark] = useState(() => window.matchMedia('(prefers-color-scheme: dark)').matches);
  const dark = appearance === 'dark' || (appearance === 'system' && systemDark);
  const [page, setPage] = useState(initialPage);
  const [state, setState] = useState(initialState);
  const [tab, setTab] = useState('sk社区');
  const [region, setRegion] = useState('河北');
  const [kind, setKind] = useState('约滑');
  const [myTab, setMyTab] = useState('我发起的');
  const [post, setPost] = useState(posts[0]);
  const [event, setEvent] = useState(events.find(e => e.id === activityId) || events[0]);
  const [own, setOwn] = useState(authorView);
  const admin = isAdmin;
  const [restriction, setRestriction] = useState(registrationState);
  const mediaState = '正常';
  const [commentState, setCommentState] = useState('正常');
  const [edit, setEdit] = useState(false);
  const [likes, setLikes] = useState<number[]>([]);
  const [saved, setSaved] = useState<number[]>([1, 3]);
  const [joined, setJoined] = useState(false);
  const [read, setRead] = useState<number[]>([1]);
  const [modal, setModal] = useState('');
  const [toast, setToast] = useState('');
  const [busy, setBusy] = useState(false);
  const [timer, setTimer] = useState(0);
  const [message, setMessage] = useState('');
  const [activeComment, setActiveComment] = useState(comments[0]);
  const [commentList, setCommentList] = useState(comments);
  const [deleted, setDeleted] = useState<number[]>([]);
  const [draft, setDraft] = useState({ title: '', body: '', type: '普通帖', region: '河北', resort: '', start: '', end: '', max: '' });
  const [media, setMedia] = useState<string[]>([]);
  const [profile, setProfile] = useState({ name: '林间一条鱼', bio: '在山里，在雪上，在自己的节奏里。', region: '河北', resort: '万龙滑雪场' });
  const [profilePhotos, setProfilePhotos] = useState({ avatar: '', cover: snow });
  const scroller = useRef<HTMLDivElement>(null);
  const scrollPositions = useRef<Record<string, number>>({});
  const touch = useRef(0);
  const navigation = useRef<string[]>([]);
  const notificationCount = notices.filter((_, i) => !read.includes(i)).length;
  const theme = { '--paper': dark ? '#101010' : '#ffffff', '--soft': dark ? '#242424' : '#f5f5f5', '--ink': dark ? '#f5f5f5' : '#171717', '--muted': dark ? '#ababab' : '#737373', '--line': dark ? '#2b2b2b' : '#eaeaea' } as CSSProperties;
  function notify(text: string) { setToast(text); window.setTimeout(() => setToast(''), 2600); }
  function go(next: string) {
    if (scroller.current) scrollPositions.current[`${page}:${tab}`] = scroller.current.scrollTop;
    navigation.current.push(page);
    setPage(next);
    setState('正常');
    setModal('');
  }
  function back() {
    setPage(navigation.current.pop() || '首页');
    setState('正常');
    setModal('');
  }
  function refresh() { setState('加载中'); window.setTimeout(() => { setState('正常'); notify('刷新成功'); }, 650); }
  function submit(text: string, next?: string) { setBusy(true); window.setTimeout(() => { setBusy(false); setModal(''); if (next) go(next); notify(text); }, 650); }
  function toggle(id: number, values: number[], setter: (v: number[]) => void, word: string) { setter(values.includes(id) ? values.filter(v => v !== id) : [...values, id]); notify(values.includes(id) ? `已取消${word}` : `${word}成功`); }
  function choosePost(p: Post) { setPost(p); setOwn(Boolean(p.own)); go('帖子详情'); }
  function saveDraft() {
    if (!draft.body.trim()) return notify('请填写正文');
    try { localStorage.setItem('skneo-design-draft', JSON.stringify(draft)); } catch { /* UI preview remains in session. */ }
    submit(edit ? '修改成功' : '发布成功', '首页');
  }
  useEffect(() => { if (scroller.current) scroller.current.scrollTop = scrollPositions.current[`${page}:${tab}`] || 0; }, [page, tab]);
  useEffect(() => {
    const query = window.matchMedia('(prefers-color-scheme: dark)');
    const change = () => setSystemDark(query.matches);
    query.addEventListener('change', change);
    return () => query.removeEventListener('change', change);
  }, []);
  useEffect(() => { if (!timer) return; const id = window.setTimeout(() => setTimer(timer - 1), 1000); return () => window.clearTimeout(id); }, [timer]);
  const submitting = busy || state === '提交中';

  function MediaStrip({ p, detail = false }: { p: Post; detail?: boolean }) {
    if (!p.images.length) return null;
    return <div className="relative mt-3"><div className="flex snap-x snap-mandatory gap-2 overflow-x-auto rounded-2xl">{p.images.map((src, i) => <button key={`${src}${i}`} aria-label={p.video ? '播放视频' : `查看第 ${i + 1} 张图片`} onClick={() => { setPost(p); setImageIndex(i); go(p.video ? '视频播放' : '图片查看'); }} className={`${detail ? 'w-[96%]' : 'w-[94%]'} relative shrink-0 snap-start overflow-hidden rounded-2xl focus-visible:ring-2`}><Photo src={src} mode={mediaState} className={`${detail ? 'aspect-[4/5]' : 'aspect-[4/5]'} w-full`} />{p.video && <span className="absolute inset-0 flex items-center justify-center"><span className="rounded-full bg-black/60 p-4 text-white"><Icon name="play" /></span></span>}</button>)}</div>{!p.video && p.images.length > 1 && <span className="pointer-events-none absolute right-5 bottom-3 rounded-md bg-black/65 px-2 py-1 text-xs text-white">{p.images.length} 图</span>}</div>;
  }
  const [imageIndex, setImageIndex] = useState(0);
  function Author({ p }: { p: Post }) {
    return <div className="flex min-w-0 items-start gap-3"><button aria-label="查看作者主页" onClick={() => { setPost(p); go('作者主页'); }} className="shrink-0 rounded-full focus-visible:ring-2"><Avatar /></button><button onClick={() => { setPost(p); go('作者主页'); }} className="min-h-11 min-w-0 text-left focus-visible:ring-2"><span className="text-base font-semibold">{p.name}</span><span className={`ml-2 text-sm ${muted}`}>{p.time}</span>{p.region && <span className={`mt-1 block text-sm ${muted}`}>常驻 {p.region}</span>}</button></div>;
  }
  function Actions({ p, detail = false }: { p: Post; detail?: boolean }) {
    return <div className="mt-1 flex gap-4"><button aria-label="点赞" aria-pressed={likes.includes(p.id)} onClick={() => toggle(p.id, likes, setLikes, '点赞')} className={`${button} -ml-3 flex items-center gap-2 text-sm ${likes.includes(p.id) ? 'text-[#c8374b]' : muted}`}><Icon name="heart" className={likes.includes(p.id) ? 'fill-current' : ''} />{p.likes + Number(likes.includes(p.id))}</button>{detail ? <button aria-pressed={saved.includes(p.id)} onClick={() => toggle(p.id, saved, setSaved, '收藏')} className={`${button} flex items-center gap-2 text-sm`}><Icon name="bookmark" className={saved.includes(p.id) ? 'fill-current' : ''} />{saved.includes(p.id) ? '已收藏' : '收藏'}</button> : <button onClick={() => choosePost(p)} className={`${button} flex items-center gap-2 text-sm ${muted}`} aria-label="查看评论"><Icon name="comment" />{p.id === 1 ? commentList.length : 0}</button>}</div>;
  }
  function Feed({ items = posts }: { items?: Post[] }) {
    return <>{items.filter(p => !deleted.includes(p.id)).map(p => <article key={p.id} className="border-b border-[var(--line)] px-4 py-5">{Author({ p })}<div className="ml-14 min-w-0"><button onClick={() => choosePost(p)} className="mt-2 block w-full text-left focus-visible:ring-2"><h3 className="text-base font-semibold leading-6">{p.title}</h3><p className="mt-1 whitespace-pre-line text-base leading-6">{p.text.length > 150 ? `${p.text.slice(0, 150)}…` : p.text}</p></button>{MediaStrip({ p })}{Actions({ p })}</div></article>)}</>;
  }
  function EventRows({ mine = false }: { mine?: boolean }) {
    const items = mine ? events.filter((e, i) => myTab === '已结束' ? e.status === 2 : myTab === '我发起的' ? i === 0 || i === 3 : i === 1) : events.filter(e => e.region === region && e.kind === kind);
    return items.length ? <>{items.map(e => <button key={e.id} onClick={() => { setEvent(e); setRestriction('可报名'); setOwn(mine && myTab === '我发起的'); go('活动详情'); }} className="block min-h-28 w-full border-b border-[var(--line)] px-5 py-6 text-left focus-visible:ring-2"><h3 className="text-base font-semibold">{e.title}</h3><div className="mt-3 flex items-center justify-between gap-2"><span className={`text-sm ${muted}`}>{e.region}{mine && ' · 一起出发，慢慢滑。'}</span>{!mine && <Chip status={e.status} />}</div></button>)}</> : <StateView state="空数据" page="活动" retry={refresh} login={() => go('登录')} />;
  }
  function CommentRows() {
    return <>{commentList.map(c => <div key={c.id} className={`flex gap-3 border-b border-[var(--line)] py-4 ${c.reply ? 'ml-11' : ''}`}><Avatar small /><div className="min-w-0 flex-1"><div className="flex items-center justify-between"><span className="text-sm font-semibold">{c.name}</span><button aria-label="评论操作菜单" onClick={() => { setActiveComment(c); setModal('评论操作'); }} className={`${button} -mr-3`}><Icon name="more" className="h-5 w-5" /></button></div><p className="text-base leading-6">{c.text}</p><div className={`mt-1 flex flex-wrap items-center gap-x-2 text-xs ${muted}`}><span>{c.time}</span><button onClick={() => toggle(c.id + 100, likes, setLikes, '点赞')} aria-label="点赞评论" aria-pressed={likes.includes(c.id + 100)} className={`${button} flex items-center gap-1 px-2`}><Icon name="heart" className={`h-4 w-4 ${likes.includes(c.id + 100) ? 'fill-current text-[#c8374b]' : ''}`} />{c.likes + Number(likes.includes(c.id + 100))}</button><button className={`${button} px-2 text-sm`} onClick={() => { setMessage(`回复 ${c.name}：`); setModal('写评论'); }}>回复</button></div></div></div>)}</>;
  }
  function PublishForm() {
    const oldMedia = edit ? post.images : [];
    return <form className="space-y-5 px-5 py-4" onSubmit={e => { e.preventDefault(); saveDraft(); }}><p className={`text-sm ${muted}`}>{edit ? '编辑动态' : draft.type === '普通帖' ? '分享雪上日常' : `发起${draft.type}`}</p>
      {edit && oldMedia.length > 0 && <div><h3 className="mb-3 text-sm">已有媒体</h3><div className="flex gap-2">{oldMedia.map((src, i) => <div key={i} className="relative h-24 w-24 overflow-hidden rounded-xl"><Photo src={src} className="h-full w-full" /><button type="button" aria-label="删除已有图片" onClick={() => setPost({ ...post, images: post.images.filter((_, n) => n !== i) })} className="absolute top-0 right-0 flex h-11 w-11 items-center justify-center rounded-full bg-black/60 text-white"><Icon name="close" className="h-4 w-4" /></button></div>)}</div></div>}
      <label className="flex min-h-28 cursor-pointer flex-col items-center justify-center gap-2 rounded-2xl border border-dashed border-[var(--line)] text-sm focus-within:ring-2"><Icon name="image" /><span>点击选择图片</span><input aria-label="选择图片或视频" type="file" accept="image/*,video/*" multiple className="sr-only" onChange={e => setMedia([...media, ...Array.from(e.target.files || []).map(f => URL.createObjectURL(f))])} /></label>
      {media.length > 0 && <div className="flex gap-2 overflow-x-auto">{media.map((src, i) => <div key={src} className="relative h-24 w-24 shrink-0 overflow-hidden rounded-xl"><Photo src={src} className="h-full w-full" /><button type="button" aria-label="移除所选媒体" onClick={() => setMedia(media.filter((_, n) => n !== i))} className="absolute top-0 right-0 flex h-11 w-11 items-center justify-center bg-black/60 text-white"><Icon name="close" className="h-4 w-4" /></button></div>)}</div>}
      <Field label="标题（可选）"><input aria-label="标题" placeholder="给这一刻起个名字" value={draft.title} onChange={e => setDraft({ ...draft, title: e.target.value })} className={input} /></Field>
      <Field label="正文 *"><textarea aria-label="正文" required rows={5} placeholder="有什么雪上新鲜事？" value={draft.body} onChange={e => setDraft({ ...draft, body: e.target.value })} className={`${input} py-3`} /></Field>
      {draft.type !== '普通帖' && <><Field label="活动地区 *"><select aria-label="活动地区" required value={draft.region} onChange={e => setDraft({ ...draft, region: e.target.value })} className={input}>{regions.map(r => <option key={r}>{r}</option>)}</select></Field>{(['resort', 'start', 'end', 'max'] as const).map((key, i) => <Field key={key} label={['雪场（可选）', '活动开始时间', '报名截止时间', '最多参与人数'][i]}><input aria-label={['雪场', '活动开始时间', '报名截止时间', '最多参与人数'][i]} type={key === 'max' ? 'number' : 'text'} min={key === 'max' ? 1 : undefined} placeholder={key === 'start' || key === 'end' ? '例如 2026-12-12 09:00' : key === 'max' ? '不填则无上限' : '输入雪场名称'} value={draft[key]} onChange={e => setDraft({ ...draft, [key]: e.target.value })} className={input} /></Field>)}</>}
      <button disabled={submitting} className={`${solid} w-full`}>{submitting ? '正在提交…' : edit ? '保存修改' : '发布'}</button></form>;
  }
  function AuthForm({ register }: { register: boolean }) {
    return <form onSubmit={e => { e.preventDefault(); submit(register ? '注册成功' : '登录成功', '我的'); }} className="space-y-5 px-6 pt-7"><h2 className="text-3xl font-bold tracking-[-1px]">skneo.</h2><div className="pb-2"><h3 className="text-2xl font-semibold">{register ? '从这里，加入雪友。' : '欢迎回到雪场。'}</h3><p className={`mt-3 text-sm ${muted}`}>记录日常，也遇见下一趟的伙伴。</p></div>{register && <><Field label="用户名"><input required aria-label="用户名" placeholder="你的雪友昵称" className={input} /></Field><Field label="常驻地区 *"><select required aria-label="常驻地区" className={input}><option value="">请选择常驻地区</option>{regions.map(r => <option key={r}>{r}</option>)}</select></Field><Field label="常驻雪场"><select aria-label="常驻雪场" className={input}>{['暂无固定雪场', '万龙滑雪场', '南山滑雪场', '松花湖滑雪场', '亚布力滑雪场'].map(r => <option key={r}>{r}</option>)}</select></Field></>}
      <Field label="邮箱"><input required aria-label="邮箱" type="email" placeholder="输入邮箱地址" className={input} /></Field><Field label="验证码"><span className="flex gap-2"><input required aria-label="6 位验证码" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} placeholder="6 位验证码" className={`${input} flex-1`} /><button type="button" disabled={timer > 0} onClick={() => { setTimer(60); notify('验证码发送状态演示，未发送邮件'); }} className={`${button} shrink-0 border border-[var(--line)] text-sm ${muted}`}>{timer ? `${timer}s 后重发` : '发送验证码'}</button></span></Field><button disabled={submitting} className={`${solid} w-full`}>{submitting ? '正在提交…' : register ? '注册' : '登录'}</button><button type="button" onClick={() => go(register ? '登录' : '注册')} className={`${button} w-full text-sm ${muted}`}>{register ? '已有账号？登录' : '还没有账号？注册'}</button></form>;
  }
  function ProfileForm() {
    return <form onSubmit={e => { e.preventDefault(); try { localStorage.setItem('skneo-design-profile', JSON.stringify(profile)); } catch { /* Local preview only. */ } submit('保存成功', '我的'); }} className="space-y-5 p-5"><div className="relative h-36 overflow-hidden rounded-2xl"><Photo src={profilePhotos.cover} className="h-full w-full" /><label className="absolute right-2 bottom-2 flex min-h-11 cursor-pointer items-center rounded-full bg-black/70 px-3 text-sm text-white">更换背景图<input aria-label="更换背景图" className="sr-only" type="file" accept="image/*" onChange={e => { if (e.target.files?.[0]) setProfilePhotos({ ...profilePhotos, cover: URL.createObjectURL(e.target.files[0]) }); }} /></label></div><label className="flex min-h-14 cursor-pointer items-center gap-3 text-sm">{profilePhotos.avatar ? <Photo src={profilePhotos.avatar} className="h-12 w-12 rounded-full" /> : <Avatar />}更换头像<input aria-label="更换头像" className="sr-only" type="file" accept="image/*" onChange={e => { if (e.target.files?.[0]) setProfilePhotos({ ...profilePhotos, avatar: URL.createObjectURL(e.target.files[0]) }); }} /></label>{(['name', 'bio'] as const).map((key, i) => <Field key={key} label={i ? '个性签名' : '昵称'}><input required={!i} aria-label={i ? '个性签名' : '昵称'} value={profile[key]} onChange={e => setProfile({ ...profile, [key]: e.target.value })} className={input} /></Field>)}<Field label="常驻地区"><select aria-label="常驻地区" className={input} value={profile.region} onChange={e => setProfile({ ...profile, region: e.target.value })}>{regions.map(r => <option key={r}>{r}</option>)}</select></Field><Field label="常驻雪场"><select aria-label="常驻雪场" value={profile.resort} onChange={e => setProfile({ ...profile, resort: e.target.value })} className={input}>{['暂无固定雪场', '万龙滑雪场', '南山滑雪场', '松花湖滑雪场'].map(r => <option key={r}>{r}</option>)}</select></Field><button disabled={submitting} className={`${solid} w-full`}>{submitting ? '正在保存…' : '保存'}</button></form>;
  }
  function Detail({ activity }: { activity: boolean }) {
    const p = activity ? { ...posts[0], title: event.title, text: '这个周末，想和同频的雪友一起出发。\n不赶路，慢慢滑。我们雪场见。' } : post;
    const blocked = own || restriction !== '可报名' || event.status !== 0;
    return <div className="px-5 pb-5"><div className="pt-3">{Author({ p: own ? { ...p, name: profile.name } : p })}</div><h2 className="mt-6 text-xl font-semibold leading-8">{p.title}</h2><p className="mt-3 whitespace-pre-line text-base leading-7">{p.text}</p>{MediaStrip({ p, detail: true })}
      {activity && <div className="my-5 rounded-2xl border border-[var(--line)] p-4"><Chip status={event.status} /><h3 className="mt-4 text-base font-semibold">{event.region} · {event.resort}</h3><dl className="mt-4 space-y-3 text-sm">{[['开始时间', '2026-12-12 09:00'], ['报名截止', '2026-12-11 18:00'], ['参与人数', `已报名 ${event.count + Number(joined)}${event.max ? ` / ${event.max}` : ''} 人`]].map(([key, v]) => <div key={key} className="flex flex-wrap justify-between gap-2"><dt className={muted}>{key}</dt><dd>{v}</dd></div>)}</dl><button disabled={blocked || submitting} onClick={() => { setJoined(!joined); submit(joined ? '取消报名成功' : '报名成功'); }} className={`${solid} mt-5 w-full`}>{submitting ? '正在提交…' : own || restriction === '我是发起人' ? '我发起的活动' : blocked ? '当前不可报名' : joined ? '取消报名' : '报名参与'}</button>{blocked && <p className={`mt-2 text-center text-xs ${muted}`}>{own ? '我是发起人' : restriction !== '可报名' ? restriction : statuses[event.status]}</p>}</div>}
      {Actions({ p, detail: true })}<div className="mt-4 border-t border-[var(--line)] pt-5"><h3 className="mb-2 text-base font-semibold">评论 ({commentState === '空数据' ? 0 : commentList.length})</h3>{commentState === '正常' ? CommentRows() : <StateView state={commentState} page="评论" retry={() => setCommentState('正常')} login={() => go('登录')} />}</div></div>;
  }
  function Body({ name }: { name: string }) {
    if (['加载中', '加载失败', '空数据', '未登录'].includes(state)) return <StateView state={state} page={name} retry={refresh} login={() => go('登录')} />;
    if (['首页', 'sk社区列表', '约约约列表'].includes(name)) {
      const eventList = name === '约约约列表' || (name === '首页' && tab === '约约约');
      return <>{eventList ? <><div className="grid grid-cols-2 gap-3 border-b border-[var(--line)] px-5 py-4"><select aria-label="浏览地区" value={region} onChange={e => setRegion(e.target.value)} className={input}>{regions.map(r => <option key={r}>{r}</option>)}</select><select aria-label="活动类型" value={kind} onChange={e => setKind(e.target.value)} className={input}>{kinds.map(k => <option key={k}>{k}</option>)}</select></div>{EventRows({})}</> : Feed({})}</>;
    }
    if (name === '帖子详情' || name === '活动详情') return Detail({ activity: name === '活动详情' });
    if (name === '发布入口') return <div className="px-5 py-6"><h2 className="text-2xl font-semibold">记录，或相约。</h2><p className={`mt-3 mb-8 text-sm ${muted}`}>留住雪上日常，遇见同频伙伴。</p>{['普通帖', '发起活动'].map((t, i) => <button key={t} onClick={() => { setEdit(false); setDraft({ ...draft, type: i ? '约滑' : '普通帖' }); go(i ? '活动类型选择' : '发布 / 编辑页'); }} className="flex min-h-24 w-full items-center gap-4 border-t border-[var(--line)] text-left focus-visible:ring-2"><Icon name={i ? 'mountain' : 'edit'} /><span className="flex-1"><b className="text-base">{t}</b><span className={`mt-2 block text-sm ${muted}`}>{i ? '约滑、约拍、约饭、约装备' : '分享文字、图片与视频'}</span></span><Icon name="arrow" className="h-4 w-4" /></button>)}</div>;
    if (name === '活动类型选择') return <div className="px-5 py-6"><h2 className="mb-2 text-2xl font-semibold">这一次，约什么？</h2><p className={`mb-6 text-sm ${muted}`}>选一种方式，和雪友相聚。</p>{kinds.map((k, i) => <button key={k} onClick={() => { setDraft({ ...draft, type: k }); setEdit(false); go('发布 / 编辑页'); }} className="flex min-h-24 w-full items-center justify-between border-b border-[var(--line)] text-left"><span><b className="text-lg">{k}</b><span className={`mt-2 block text-sm ${muted}`}>{['一起滑，下一趟有人作伴', '记录彼此的雪上瞬间', '收板之后，吃顿热的', '聊聊新雪季的装备'][i]}</span></span><Icon name="arrow" className="h-4 w-4" /></button>)}</div>;
    if (name === '发布 / 编辑页') return PublishForm();
    if (name === '登录' || name === '注册') return AuthForm({ register: name === '注册' });
    if (name === '编辑资料') return ProfileForm();
    if (['私信占位', '社区服务', '设置', '关于 Snow Fish'].includes(name)) return <p className={`px-6 py-24 text-center text-sm leading-7 ${muted}`}>{name === '关于 Snow Fish' ? 'Snow Fish，属于滑雪人的日常社区。' : `${name === '私信占位' ? '私信' : name}功能暂未开放。`}</p>;
    if (name === '通知') return <>{notices.map((n, i) => <button key={n} onClick={() => { setRead([...new Set([...read, i])]); if (i < 2) go('活动详情'); else notify('举报已处理，无需进一步操作'); }} className="flex min-h-28 w-full gap-3 border-b border-[var(--line)] px-5 py-5 text-left"><span className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-full ${read.includes(i) ? `bg-[var(--soft)] ${muted}` : 'bg-[var(--ink)] text-[var(--paper)]'}`}><Icon name={i === 2 ? 'check' : 'bell'} className="h-5 w-5" /></span><span className="min-w-0 flex-1"><span className={`block text-base ${read.includes(i) ? '' : 'font-semibold'}`}>{n}</span><span className={`mt-2 block text-sm leading-6 ${muted}`}>{i === 2 ? '感谢你对社区环境的维护，相关内容已核查。' : events[0].title}</span><span className={`mt-2 block text-xs ${muted}`}>{read.includes(i) ? '已读' : '未读'} · {i + 1} 小时前</span></span>{i < 2 && <Icon name="arrow" className={`mt-3 h-4 w-4 ${muted}`} />}</button>)}</>;
    if (name === '我的' || name === '作者主页') return <><Photo src={profilePhotos.cover} className="h-[150px] w-full" /><div className="px-5"><div className="relative -mt-6 flex items-end justify-between"><span className="rounded-full border-4 border-[var(--paper)]">{profilePhotos.avatar && name === '我的' ? <Photo src={profilePhotos.avatar} className="h-14 w-14 rounded-full" /> : <Avatar />}</span>{name === '我的' ? <button className={`${button} mt-8 border border-[var(--line)] text-sm font-semibold`} onClick={() => go('编辑资料')}>编辑资料</button> : <button className={button} aria-label="举报用户" onClick={() => setModal('举报')}><Icon name="alert" /></button>}</div><h2 className="mt-4 text-2xl font-semibold">{name === '我的' ? profile.name : post.name}</h2><p className="mt-2 text-base leading-6">{profile.bio}</p><p className={`mt-3 text-sm ${muted}`}>常驻 {profile.region} · {profile.resort}</p>{name === '我的' && <div className="mt-6 divide-y divide-[var(--line)] border-y border-[var(--line)]">{['我的帖子', '我的评论', '我的收藏', '我的活动', '通知', '社区服务', '关于 Snow Fish', '设置', ...(admin ? ['内容治理中心'] : [])].map(t => <button key={t} onClick={() => go(t)} className="flex min-h-14 w-full items-center justify-between text-sm focus-visible:ring-2">{t}<Icon name="arrow" className={`h-4 w-4 ${muted}`} /></button>)}</div>}<h3 className="mt-7 mb-3 text-base font-semibold">{name === '我的' ? '我' : 'TA'}发布的动态</h3>{posts.filter(p => name === '我的' ? p.own : p.id === post.id).map(p => <button key={p.id} onClick={() => choosePost(p)} className="flex w-full items-center gap-3 border-t border-[var(--line)] py-5 text-left"><span className="min-w-0 flex-1"><b className="text-base">{p.title}</b><span className={`mt-2 block truncate text-sm ${muted}`}>{p.text}</span></span><Icon name="arrow" className="h-4 w-4" /></button>)}</div></>;
    if (name === '我的帖子') return <>{posts.filter(p => p.own && !deleted.includes(p.id)).map(p => <div key={p.id} className="border-b border-[var(--line)] p-5"><button onClick={() => choosePost(p)} className="w-full text-left"><h3 className="text-base font-semibold">{p.title}</h3><p className={`mt-2 text-sm leading-6 ${muted}`}>{p.text}</p></button><div className="mt-2 flex gap-3"><button onClick={() => { setPost(p); setEdit(true); setDraft({ ...draft, title: p.title, body: p.text }); go('发布 / 编辑页'); }} className={`${button} -ml-3 text-sm`}>编辑</button><button onClick={() => { setPost(p); setModal('删除动态'); }} className={`${button} text-sm text-[#bc3444]`}>删除</button></div></div>)}</>;
    if (name === '我的收藏') return Feed({ items: posts.filter(p => saved.includes(p.id)) });
    if (name === '我的评论') return <div className="px-5">{comments.filter(c => c.own).map(c => <button key={c.id} onClick={() => choosePost(posts[0])} className="block w-full border-b border-[var(--line)] py-6 text-left"><p className="text-base leading-7">{c.text}</p><span className={`mt-3 block text-sm ${muted}`}>评论于「{posts[0].title}」</span><span className={`mt-2 block text-xs ${muted}`}>{c.time}</span></button>)}</div>;
    if (name === '我的活动') return <><Tabs items={['我发起的', '我参与的', '已结束']} value={myTab} onChange={setMyTab} />{EventRows({ mine: true })}</>;
    if (name === '图片查看') return <div className="flex h-full flex-col justify-center bg-[#101010] text-white" onTouchStart={e => { touch.current = e.touches[0].clientX; }} onTouchEnd={e => { const d = touch.current - e.changedTouches[0].clientX; if (Math.abs(d) > 50) setImageIndex(Math.min(Math.max(imageIndex + (d > 0 ? 1 : -1), 0), post.images.length - 1)); }}><Photo src={post.images[imageIndex] || snow} className="aspect-[3/4] w-full" mode={mediaState} /><div className="mt-6 flex items-center justify-center gap-8"><button aria-label="上一张" disabled={imageIndex === 0} onClick={() => setImageIndex(imageIndex - 1)} className={`${button} disabled:text-neutral-500`}><Icon name="back" /></button><span className="text-sm">{imageIndex + 1} / {post.images.length}</span><button aria-label="下一张" disabled={imageIndex >= post.images.length - 1} onClick={() => setImageIndex(imageIndex + 1)} className={`${button} disabled:text-neutral-500`}><Icon name="arrow" /></button></div></div>;
    if (name === '视频播放') return <div className="flex h-full flex-col justify-center bg-[#101010]"><video aria-label="雪上视频播放预览" poster={ski} controls playsInline className="max-h-full w-full" /></div>;
    if (name === '内容治理中心') return <div className="px-5">{reports.map(r => <article key={r.title} className="border-b border-[var(--line)] py-5"><div className="flex items-start justify-between gap-2"><h3 className="pt-2 text-base font-semibold">{r.title}</h3><button aria-label="举报处理菜单" onClick={() => { setMessage(''); setModal('处理举报'); }} className={button}><Icon name="more" /></button></div><dl className="mt-3 space-y-3 text-sm">{[['举报原因', r.reason], ['补充说明', r.note], ['内容摘要', r.excerpt]].map(([k, v]) => <div key={k}><dt className={`mb-1 text-xs ${muted}`}>{k}</dt><dd className="leading-6">{v}</dd></div>)}</dl></article>)}</div>;
    return null;
  }
  function Nav({ name }: { name: string }) {
    const selected = ['首页', 'sk社区列表', '约约约列表'].includes(name) ? '首页' : ['我的', '我的帖子', '我的评论', '我的收藏', '我的活动'].includes(name) ? '我的' : name === '私信占位' ? '私信' : name;
    return <nav aria-label="底部导航" className="mx-3 mt-2 mb-[max(12px,env(safe-area-inset-bottom))] grid shrink-0 grid-cols-5 rounded-full border border-[var(--line)] bg-[var(--paper)] p-2 shadow-[0_8px_30px_#00000008]">{(['首页', '私信', '发布', '通知', '我的'] as const).map((t, i) => <button key={t} aria-label={t === '通知' ? `通知，${notificationCount} 条未读` : t} aria-pressed={t === '发布' ? undefined : selected === t} onClick={() => go(t === '发布' ? state === '未登录' ? '登录' : '发布入口' : t === '私信' ? '私信占位' : t)} className={`${button} relative flex flex-col items-center gap-1 px-0 text-xs`}><span className={`flex h-10 w-full items-center justify-center rounded-full ${selected === t ? 'bg-[var(--soft)]' : ''}`}><Icon name={(['home', 'mail', 'plus', 'bell', 'user'] as Glyph[])[i]} className={selected === t && t === '首页' ? 'fill-current' : ''} /></span>{t === '通知' && notificationCount > 0 && <span className="absolute top-0 right-2 rounded-full bg-[#c6374c] px-1.5 text-xs text-white">{notificationCount > 99 ? '99+' : notificationCount}</span>}{t}</button>)}</nav>;
  }
  function Overlay() {
    if (!modal) return null;
    return <Sheet title={modal} close={() => setModal('')}>{modal === '写评论' || modal === '编辑评论' ? <form onSubmit={e => { e.preventDefault(); if (!message.trim()) return notify('请输入评论内容'); const time = new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' }); setCommentList(modal === '编辑评论' ? commentList.map(c => c.id === activeComment.id ? { ...c, text: message, time } : c) : [...commentList, { id: Date.now(), name: profile.name, text: message, time, likes: 0, reply: message.startsWith('回复'), own: true }]); setMessage(''); submit('评论成功'); }} className="space-y-4"><textarea aria-label="评论内容" autoFocus value={message} onChange={e => setMessage(e.target.value)} rows={4} className={`${input} py-3`} placeholder="写下你的想法…" /><button disabled={submitting} className={`${solid} w-full`}>{submitting ? '正在提交…' : '发布评论'}</button></form> : modal === '评论操作' ? <div className="space-y-2">{(activeComment.own ? ['编辑', '删除', '举报'] : ['举报']).map(t => <button key={t} onClick={() => { if (t === '编辑') { setMessage(activeComment.text); setModal('编辑评论'); } else if (t === '删除') { setCommentList(commentList.filter(c => c.id !== activeComment.id)); setModal(''); notify('删除成功'); } else setModal('举报'); }} className={`${button} w-full border-b border-[var(--line)] text-left text-base`}>{t}</button>)}</div> : modal === '举报' ? <form className="space-y-4" onSubmit={e => { e.preventDefault(); submit('举报成功'); }}><Field label="举报原因"><select aria-label="举报原因" className={input}>{['违规内容', '垃圾信息', '不友善内容', '其他'].map(t => <option key={t}>{t}</option>)}</select></Field><Field label="补充说明"><textarea aria-label="举报补充说明" rows={3} className={`${input} py-3`} /></Field><button disabled={submitting} className={`${solid} w-full`}>{submitting ? '正在提交…' : '提交举报'}</button></form> : modal === '处理举报' ? <form className="space-y-4" onSubmit={e => { e.preventDefault(); if (!message.trim()) return notify('请输入处理说明'); submit('处理成功'); }}><Field label="处理方式"><select aria-label="处理方式" className={input}>{['置顶 7 天', '取消置顶', '确认违规并下架', '无需处理'].map(t => <option key={t}>{t}</option>)}</select></Field><Field label="处理说明 *"><textarea required aria-label="处理说明" rows={3} value={message} onChange={e => setMessage(e.target.value)} className={`${input} py-3`} /></Field><button disabled={submitting} className={`${solid} w-full`}>{submitting ? '正在处理…' : '确认处理'}</button></form> : modal === '删除动态' ? <div className="space-y-5"><p className={`text-sm leading-6 ${muted}`}>删除后，该动态将不再显示。确定要删除吗？</p><button onClick={() => { setDeleted([...deleted, post.id]); setModal(''); go('我的帖子'); notify('删除成功'); }} className={`${solid} w-full`}>确认删除</button><button className={`${button} w-full text-sm`} onClick={() => setModal('')}>取消</button></div> : <p className={`text-sm leading-7 ${muted}`}>Skneo Web · 界面设计预览<br />版本 1.0.0 · 构建信息示意<br />仅展示界面，无服务端连接。</p>}</Sheet>;
  }
  function Screen({ name }: { name: string }) {
    const detail = ['帖子详情', '活动详情'].includes(name);
    const hasNav = ['首页', 'sk社区列表', '约约约列表', '私信占位', '通知', '我的'].includes(name);
    const darkMedia = ['图片查看', '视频播放'].includes(name);
    return <div className="relative flex h-[100dvh] min-h-0 w-full flex-col overflow-hidden bg-[var(--paper)] pt-[env(safe-area-inset-top)]">
      <div className={`flex min-h-16 shrink-0 items-center justify-between gap-1 px-3 ${darkMedia ? 'bg-[#101010] text-white' : ''}`}>
        {['首页', 'sk社区列表', '约约约列表'].includes(name) ? <><span className="w-11" /><h2 className="text-[28px] font-bold tracking-[-1.5px]">skneo.</h2><span className="w-11" /></> : <><button aria-label="返回" onClick={back} className={`${button} px-2`}><Icon name={darkMedia ? 'close' : 'back'} /></button><h2 className={`min-w-0 flex-1 text-center font-semibold ${detail && own ? 'text-sm' : 'text-lg'}`}>{name === '发布 / 编辑页' ? edit ? '编辑动态' : '发布动态' : name === '私信占位' ? '私信' : name === '图片查看' ? '' : name === '作者主页' ? '雪友主页' : name}</h2>{detail ? <div className="flex shrink-0 items-center"><button aria-label="举报帖子" onClick={() => setModal('举报')} className={`${button} px-2`}><Icon name="alert" className="h-5 w-5" /></button>{own && <><button aria-label="编辑帖子" onClick={() => { setEdit(true); setDraft({ ...draft, title: post.title, body: post.text }); go('发布 / 编辑页'); }} className={`${button} px-2`}><Icon name="edit" className="h-5 w-5" /></button><button aria-label="删除帖子" onClick={() => setModal('删除动态')} className={`${button} px-2`}><Icon name="trash" className="h-5 w-5" /></button></>}</div> : name === '通知' ? <button onClick={() => { setRead([0, 1, 2]); notify('已全部标为已读'); }} className={`${button} px-1 text-sm`}>全部已读</button> : name === '内容治理中心' ? <button onClick={() => setModal('构建信息')} className={`${button} px-1 text-xs ${muted}`}>v1.0.0</button> : <span className="w-11" />}</>}
      </div>
      {['首页', 'sk社区列表', '约约约列表'].includes(name) && <Tabs items={['sk社区', '约约约']} value={name === '首页' ? tab : name === '约约约列表' ? '约约约' : 'sk社区'} onChange={t => { if (scroller.current) scrollPositions.current[`${page}:${tab}`] = scroller.current.scrollTop; setTab(t); if (name !== '首页') go(t === 'sk社区' ? 'sk社区列表' : '约约约列表'); }} />}
      <div ref={scroller} onTouchStart={e => { touch.current = e.touches[0].clientY; }} onTouchEnd={e => { if ((scroller.current?.scrollTop || 0) === 0 && e.changedTouches[0].clientY - touch.current > 80) refresh(); }} className={`min-h-0 flex-1 overflow-x-hidden overflow-y-auto ${darkMedia ? 'bg-[#101010]' : ''}`}>{Body({ name })}</div>
      {detail && <button onClick={() => { setMessage(''); setModal('写评论'); }} className={`${button} mx-4 mt-2 mb-5 flex shrink-0 items-center gap-3 rounded-full bg-[var(--soft)] px-5 py-3 text-left text-base ${muted}`}><Icon name="comment" className="h-5 w-5" />写评论…</button>}{hasNav && Nav({ name })}
      <>{Overlay()}{(toast || state === '操作成功' || state === '操作失败' || (state === '提交中' && !detail && name !== '发布 / 编辑页')) && <div role="status" className="absolute right-4 bottom-28 left-4 z-50 flex items-center gap-2 rounded-xl bg-[var(--ink)] px-4 py-3 text-sm text-[var(--paper)] shadow-lg"><Icon name={state === '操作失败' ? 'alert' : state === '提交中' ? 'more' : 'check'} className="h-5 w-5" />{toast || (state === '操作失败' ? '操作失败，请稍后重试' : state === '提交中' ? '正在提交，请稍候…' : '操作成功')}</div>}</>
    </div>;
  }
  return <div style={theme} className="min-h-[100dvh] overflow-x-hidden bg-[var(--paper)] font-sans text-[var(--ink)]">
    <main className="mx-auto min-w-0 w-full max-w-[600px]" aria-label="skneo 滑雪社区">
      {Screen({ name: page })}
    </main>
  </div>;
}
