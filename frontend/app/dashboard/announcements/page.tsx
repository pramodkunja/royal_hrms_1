"use client";

import { useState } from "react";

type Category = "general" | "policy" | "events" | "celebrations";

interface Post {
  id: number;
  authorInitials: string;
  authorName: string;
  authorRole: string;
  timeAgo: string;
  pinned: boolean;
  category: Category;
  title: string;
  content: string;
  reactions: number;
  comments: number;
  views: number;
  branch: string;
  visibility: string;
}

interface FormState {
  title: string;
  category: Category | "";
  visibility: string;
  branch: string;
  body: string;
  pin: boolean;
  emailNotification: boolean;
}

type FormErrors = Partial<Record<"title" | "category" | "body", string>>;

const BRANCHES          = ["All Branches", "Head Office", "North Branch", "South Branch", "East Branch", "West Branch"];
const VISIBILITY_OPTIONS = ["All Employees", "Managers Only", "HR Only", "Specific Branch"];
const CATEGORIES: { value: Category; label: string }[] = [
  { value: "general",      label: "General"      },
  { value: "policy",       label: "Policy"       },
  { value: "events",       label: "Events"       },
  { value: "celebrations", label: "Celebrations" },
];
const FILTERS = ["All Posts", "General", "Policy", "Events", "Celebrations"];

const EMPTY_FORM: FormState = {
  title: "", category: "", visibility: "All Employees",
  branch: "All Branches", body: "", pin: false, emailNotification: true,
};

const INITIAL_POSTS: Post[] = [
  {
    id: 1, authorInitials: "SV", authorName: "Sunil Varghese",
    authorRole: "Managing Director", timeAgo: "2 hours ago",
    pinned: true, category: "celebrations",
    title: "Diwali Bonus Announced — 1 Month Extra! 🎉",
    content: "Dear team, in recognition of an outstanding Q3, the management is delighted to announce a Diwali bonus equivalent to one month gross salary for all confirmed employees. The bonus will be credited along with November payroll. Wishing everyone a sparkling festival season!",
    reactions: 42, comments: 8, views: 54, branch: "All Branches", visibility: "All Employees",
  },
  {
    id: 2, authorInitials: "KR", authorName: "Kavitha Rajan",
    authorRole: "HR Admin", timeAgo: "Yesterday",
    pinned: true, category: "policy",
    title: "Updated Work From Home Policy — Effective November 1st",
    content: "Please be informed that the Work From Home policy has been revised. Employees are now permitted up to 2 WFH days per week subject to manager approval. The revised policy document has been uploaded to the Document Center for reference.",
    reactions: 31, comments: 5, views: 72, branch: "All Branches", visibility: "All Employees",
  },
  {
    id: 3, authorInitials: "AR", authorName: "Arun Raj",
    authorRole: "HR Manager", timeAgo: "3 days ago",
    pinned: false, category: "events",
    title: "Annual Company Picnic — Register by October 20th",
    content: "We are thrilled to announce our Annual Company Picnic scheduled for October 28th at Cubbon Park. This is a great opportunity to bond with your colleagues outside the office. Please register via the My Requests section before October 20th.",
    reactions: 19, comments: 12, views: 48, branch: "Head Office", visibility: "All Employees",
  },
  {
    id: 4, authorInitials: "PM", authorName: "Priya Menon",
    authorRole: "IT Admin", timeAgo: "5 days ago",
    pinned: false, category: "general",
    title: "Scheduled Server Maintenance — October 15th, 11 PM to 2 AM",
    content: "The IT team will be conducting scheduled maintenance on our servers on October 15th from 11:00 PM to 2:00 AM IST. During this window the HRMS portal and email services may be temporarily unavailable. Please plan your work accordingly.",
    reactions: 15, comments: 3, views: 11, branch: "All Branches", visibility: "All Employees",
  },
];

const CAT_BADGE: Record<Category, string> = {
  general:      "bg-[#e6f1fb] text-[#0e7c86]",
  policy:       "bg-[#fef3c7] text-[#b5651d]",
  events:       "bg-[#d8f3dc] text-[#1b8a6b]",
  celebrations: "bg-[#ecd9a0] text-[#c99a2e]",
};
const CAT_LABEL: Record<Category, string> = {
  general: "General", policy: "Policy", events: "Events", celebrations: "Celebrations",
};
const STAT_ICON_CLS = [
  "bg-[rgba(30,78,140,0.10)] text-[#1e4e8c]",
  "bg-[#fef3c7] text-[#b5651d]",
  "bg-[#d8f3dc] text-[#1b8a6b]",
  "bg-[#e6f1fb] text-[#0e7c86]",
];

const INPUT_BASE =
  "w-full px-3 py-2.5 rounded-lg border text-[13px] bg-[var(--bg-low)] text-[var(--on-bg)] placeholder:text-[var(--outline)] focus:outline-none transition-colors";

export default function AnnouncementsPage() {
  const [posts, setPosts]               = useState<Post[]>(INITIAL_POSTS);
  const [activeFilter, setActiveFilter] = useState("All Posts");
  const [showModal, setShowModal]       = useState(false);
  const [editPost, setEditPost]         = useState<Post | null>(null);
  const [form, setForm]                 = useState<FormState>(EMPTY_FORM);
  const [errors, setErrors]             = useState<FormErrors>({});

  const filtered =
    activeFilter === "All Posts"
      ? posts
      : posts.filter(p => p.category === activeFilter.toLowerCase());

  const stats = [
    { label: "Total Posts",     value: posts.length,                               icon: "ti-speakerphone" },
    { label: "Pinned",          value: posts.filter(p => p.pinned).length,         icon: "ti-pin"          },
    { label: "Total Reactions", value: posts.reduce((a, p) => a + p.reactions, 0), icon: "ti-heart"        },
    { label: "Total Views",     value: posts.reduce((a, p) => a + p.views, 0),     icon: "ti-eye"          },
  ];

  function openNew() {
    setEditPost(null); setForm(EMPTY_FORM); setErrors({}); setShowModal(true);
  }
  function openEdit(post: Post) {
    setEditPost(post);
    setForm({ title: post.title, category: post.category, visibility: post.visibility,
      branch: post.branch, body: post.content, pin: post.pinned, emailNotification: false });
    setErrors({}); setShowModal(true);
  }
  function closeModal() {
    setShowModal(false); setEditPost(null); setForm(EMPTY_FORM); setErrors({});
  }
  function setField(key: keyof FormState, val: string | boolean) {
    setForm(f => ({ ...f, [key]: val }));
  }
  function validate(): boolean {
    const e: FormErrors = {};
    if (!form.title.trim()) e.title    = "Title is required";
    if (!form.category)     e.category = "Category is required";
    if (!form.body.trim())  e.body     = "Body is required";
    setErrors(e);
    return !Object.keys(e).length;
  }
  function handleSubmit() {
    if (!validate()) return;
    if (editPost) {
      setPosts(prev => prev.map(p =>
        p.id === editPost.id
          ? { ...p, title: form.title, category: form.category as Category,
              content: form.body, pinned: form.pin,
              visibility: form.visibility, branch: form.branch }
          : p
      ));
    } else {
      setPosts(prev => [{
        id: Date.now(), authorInitials: "RS", authorName: "Ravi Shankar",
        authorRole: "System Admin", timeAgo: "Just now",
        pinned: form.pin, category: form.category as Category,
        title: form.title, content: form.body,
        reactions: 0, comments: 0, views: 0,
        branch: form.branch, visibility: form.visibility,
      }, ...prev]);
    }
    closeModal();
  }

  return (
    <div>

      {/* ── Page Header ── */}
      <div className="flex items-start justify-between flex-wrap gap-3 mb-6">
        <div>
          <h1 className="text-[22px] font-bold text-[var(--on-bg)] tracking-tight mb-1">
            Announcements
          </h1>
          <p className="text-[13px] text-[var(--on-variant)]">
            Company updates, policies, and important news
          </p>
        </div>
        <button
          onClick={openNew}
          className="flex items-center gap-1.5 px-4 py-[9px] bg-[#1e4e8c] text-white rounded-lg text-[13px] font-semibold hover:bg-[#163d72] transition-colors shadow-sm"
        >
          <i className="ti ti-plus text-base" />
          Post Announcement
        </button>
      </div>

      {/* ── Stats Row ── */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4 mb-6">
        {stats.map((st, i) => (
          <div key={st.label}
            className="bg-white rounded-xl border border-[var(--outline-v)] p-4 sm:p-5 flex items-center justify-between hover:shadow-md transition-shadow"
          >
            <div>
              <div className="text-[11px] sm:text-[12px] font-medium text-[var(--on-variant)] mb-1">{st.label}</div>
              <div className="text-[22px] sm:text-[28px] font-bold text-[var(--on-bg)] leading-none tracking-tight">{st.value}</div>
            </div>
            <div className={`w-9 h-9 sm:w-[42px] sm:h-[42px] rounded-[10px] flex items-center justify-center text-lg sm:text-xl flex-shrink-0 ${STAT_ICON_CLS[i]}`}>
              <i className={`ti ${st.icon}`} />
            </div>
          </div>
        ))}
      </div>

      {/* ── Filter Tabs ── */}
      <div className="flex items-center gap-2 flex-wrap mb-5">
        {FILTERS.map(f => (
          <button
            key={f}
            onClick={() => setActiveFilter(f)}
            className={`px-3 sm:px-4 py-[6px] sm:py-[7px] rounded-full text-[12px] sm:text-[13px] font-medium border transition-all ${
              activeFilter === f
                ? "bg-[#1e4e8c] text-white border-[#1e4e8c]"
                : "bg-white text-[var(--on-variant)] border-[var(--outline-v)] hover:border-[#1e4e8c] hover:text-[#1e4e8c]"
            }`}
          >
            {f}
          </button>
        ))}
      </div>

      {/* ── Posts List ── */}
      <div className="flex flex-col gap-3.5">
        {filtered.length === 0 ? (
          <div className="bg-white rounded-xl border border-[var(--outline-v)] p-10 text-center">
            <i className="ti ti-speakerphone text-4xl text-[var(--outline)] block mb-3" />
            <p className="text-[13px] text-[var(--on-variant)]">No announcements in this category.</p>
          </div>
        ) : filtered.map(post => (
          <div
            key={post.id}
            className={`bg-white rounded-xl border border-[var(--outline-v)] p-4 sm:p-5 transition-shadow hover:shadow-[0_4px_16px_rgba(30,78,140,0.08)] border-l-4 ${
              post.pinned ? "border-l-[#c99a2e]" : "border-l-transparent"
            }`}
          >
            {/* Author row */}
            <div className="flex items-start justify-between gap-3 mb-3 flex-wrap">
              <div className="flex items-center gap-2.5 min-w-0">
                <div className="w-9 h-9 rounded-full bg-[#1e4e8c] text-white flex items-center justify-center text-[13px] font-semibold flex-shrink-0">
                  {post.authorInitials}
                </div>
                <div className="min-w-0">
                  <div className="text-[14px] font-semibold text-[var(--on-bg)] leading-tight truncate">{post.authorName}</div>
                  <div className="text-[12px] text-[var(--on-variant)] mt-0.5">{post.authorRole} · {post.timeAgo}</div>
                </div>
              </div>
              <div className="flex items-center gap-1.5 flex-shrink-0 flex-wrap">
                {post.pinned && (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-[#ecd9a0] text-[#c99a2e]">
                    <i className="ti ti-pin text-[10px]" /> PINNED
                  </span>
                )}
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-medium ${CAT_BADGE[post.category]}`}>
                  {CAT_LABEL[post.category]}
                </span>
              </div>
            </div>

            {/* Title & content */}
            <div className="text-[14px] sm:text-[15px] font-semibold text-[var(--on-bg)] mb-1.5 leading-snug">{post.title}</div>
            <div className="text-[13px] text-[var(--on-variant)] leading-relaxed mb-4">{post.content}</div>

            {/* Footer */}
            <div className="flex items-center justify-between gap-3 flex-wrap">
              <div className="flex items-center gap-3 sm:gap-4 flex-wrap">
                <span className="flex items-center gap-1.5 text-[12px] text-[var(--on-variant)]">
                  <i className="ti ti-heart text-[14px] text-[var(--outline)]" />{post.reactions}
                </span>
                <span className="flex items-center gap-1.5 text-[12px] text-[var(--on-variant)]">
                  <i className="ti ti-message-circle text-[14px] text-[var(--outline)]" />{post.comments} comments
                </span>
                <span className="flex items-center gap-1.5 text-[12px] text-[var(--on-variant)]">
                  <i className="ti ti-eye text-[14px] text-[var(--outline)]" />{post.views} views
                </span>
              </div>
              <button
                onClick={() => openEdit(post)}
                title="Edit"
                className="w-8 h-8 flex items-center justify-center rounded-lg text-[13px] text-[var(--outline)] border border-transparent hover:bg-[var(--bg-low)] hover:border-[var(--outline-v)] hover:text-[#1e4e8c] transition-all"
              >
                <i className="ti ti-pencil" />
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* ══════════════════ MODAL ══════════════════ */}
      {showModal && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 backdrop-blur-sm"
          style={{ background: "rgba(10,20,40,0.40)" }}
          onClick={e => { if (e.target === e.currentTarget) closeModal(); }}
        >
          <div
            className="bg-white rounded-xl shadow-2xl w-full max-w-lg flex flex-col"
            style={{ maxHeight: "90vh" }}
          >
            {/* Modal header */}
            <div className="flex items-center justify-between px-5 sm:px-6 py-4 border-b border-[var(--outline-v)] flex-shrink-0">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-[rgba(30,78,140,0.10)] flex items-center justify-center flex-shrink-0">
                  <i className="ti ti-speakerphone text-[16px] text-[#1e4e8c]" />
                </div>
                <h2 className="text-[15px] font-semibold text-[var(--on-bg)]">
                  {editPost ? "Edit Announcement" : "Post New Announcement"}
                </h2>
              </div>
              <button
                onClick={closeModal}
                className="w-8 h-8 flex items-center justify-center rounded-lg text-[var(--on-variant)] hover:bg-[var(--bg-low)] transition-colors flex-shrink-0"
              >
                <i className="ti ti-x text-[18px]" />
              </button>
            </div>

            {/* Modal body */}
            <div className="px-5 sm:px-6 py-5 space-y-4 overflow-y-auto flex-1">

              {/* Title */}
              <div>
                <label className="block text-[12px] font-semibold text-[var(--on-variant)] uppercase tracking-wide mb-1.5">
                  Title <span className="text-[var(--error)] normal-case tracking-normal">*</span>
                </label>
                <input
                  type="text"
                  placeholder="e.g. Diwali Bonus Announcement"
                  value={form.title}
                  onChange={e => setField("title", e.target.value)}
                  className={`${INPUT_BASE} ${errors.title ? "border-[var(--error)] focus:border-[var(--error)]" : "border-[var(--outline-v)] focus:border-[#1e4e8c]"}`}
                />
                {errors.title && <p className="text-[11px] text-[var(--error)] mt-1">{errors.title}</p>}
              </div>

              {/* Category + Visibility */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-[12px] font-semibold text-[var(--on-variant)] uppercase tracking-wide mb-1.5">
                    Category <span className="text-[var(--error)] normal-case tracking-normal">*</span>
                  </label>
                  <select
                    value={form.category}
                    onChange={e => setField("category", e.target.value)}
                    className={`${INPUT_BASE} ${errors.category ? "border-[var(--error)] focus:border-[var(--error)]" : "border-[var(--outline-v)] focus:border-[#1e4e8c]"}`}
                  >
                    <option value="">Select category...</option>
                    {CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
                  </select>
                  {errors.category && <p className="text-[11px] text-[var(--error)] mt-1">{errors.category}</p>}
                </div>
                <div>
                  <label className="block text-[12px] font-semibold text-[var(--on-variant)] uppercase tracking-wide mb-1.5">
                    Visibility
                  </label>
                  <select
                    value={form.visibility}
                    onChange={e => setField("visibility", e.target.value)}
                    className={`${INPUT_BASE} border-[var(--outline-v)] focus:border-[#1e4e8c]`}
                  >
                    {VISIBILITY_OPTIONS.map(v => <option key={v} value={v}>{v}</option>)}
                  </select>
                </div>
              </div>

              {/* Branch */}
              <div>
                <label className="block text-[12px] font-semibold text-[var(--on-variant)] uppercase tracking-wide mb-1.5">
                  Branch
                </label>
                <select
                  value={form.branch}
                  onChange={e => setField("branch", e.target.value)}
                  className={`${INPUT_BASE} border-[var(--outline-v)] focus:border-[#1e4e8c]`}
                >
                  {BRANCHES.map(b => <option key={b} value={b}>{b}</option>)}
                </select>
              </div>

              {/* Body */}
              <div>
                <label className="block text-[12px] font-semibold text-[var(--on-variant)] uppercase tracking-wide mb-1.5">
                  Body <span className="text-[var(--error)] normal-case tracking-normal">*</span>
                </label>
                <textarea
                  rows={5}
                  placeholder="Write your announcement..."
                  value={form.body}
                  onChange={e => setField("body", e.target.value)}
                  className={`${INPUT_BASE} resize-none ${errors.body ? "border-[var(--error)] focus:border-[var(--error)]" : "border-[var(--outline-v)] focus:border-[#1e4e8c]"}`}
                />
                {errors.body && <p className="text-[11px] text-[var(--error)] mt-1">{errors.body}</p>}
              </div>

              {/* Checkboxes */}
              <div className="flex items-center gap-4 sm:gap-6 flex-wrap pt-1">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.pin}
                    onChange={e => setField("pin", e.target.checked)}
                    className="w-4 h-4 rounded cursor-pointer accent-[#1e4e8c]"
                  />
                  <span className="text-[13px] text-[var(--on-bg)]">Pin this announcement</span>
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.emailNotification}
                    onChange={e => setField("emailNotification", e.target.checked)}
                    className="w-4 h-4 rounded cursor-pointer accent-[#1e4e8c]"
                  />
                  <span className="text-[13px] text-[var(--on-bg)]">Send email notification</span>
                </label>
              </div>
            </div>

            {/* Modal footer */}
            <div className="flex items-center justify-end gap-3 px-5 sm:px-6 py-4 border-t border-[var(--outline-v)] flex-shrink-0">
              <button
                onClick={closeModal}
                className="px-4 py-[9px] rounded-lg text-[13px] font-medium border border-[var(--outline-v)] text-[var(--on-bg)] bg-white hover:bg-[var(--bg-low)] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSubmit}
                className="flex items-center gap-2 px-4 sm:px-5 py-[9px] rounded-lg text-[13px] font-semibold bg-[#1e4e8c] text-white hover:bg-[#163d72] transition-colors shadow-sm"
              >
                <i className="ti ti-send text-[15px]" />
                {editPost ? "Save Changes" : "Post Announcement"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
