/**
 * Redmine AI Assistant - Chat Widget
 * 悬浮宠物图标 + AI 对话窗口（Vanilla JS，兼容 Redmine 7 Propshaft）
 *
 * Features:
 * - localStorage 浏览器本地历史持久化
 * - 完整 Markdown + 安全 HTML 渲染
 * - 报告周期选择（今日/昨日、本周/上周、本月/上月）
 */
(function () {
  "use strict";

  const STORAGE_PREFIX = "ai_chat_";
  const MAX_STORED_MESSAGES = 200;

  // 周期选项标签映射
  const PERIOD_OPTIONS = {
    daily:   { "0": "今日日报",  "-1": "昨日日报" },
    weekly:  { "0": "本周周报",  "-1": "上周周报" },
    monthly: { "0": "本月月报",  "-1": "上月月报" }
  };

  class AIChatWidget {
    constructor() {
      this.conversationId = this.generateId();
      this.isProcessing = false;
      this.csrfToken = "";
      this.messagesData = []; // { role, content, isError }
      this.pendingReportType = null; // 用户选择的报告类型
      this.elements = {};
      this.init();
    }

    init() {
      const container = document.getElementById("ai-chat-widget");
      if (!container) return;

      this.csrfToken = container.dataset.aiChatCsrfValue ||
        document.querySelector('meta[name="csrf-token"]')?.content || "";

      this.elements = {
        container: container,
        toggle: document.getElementById("ai-chat-toggle"),
        window: document.getElementById("ai-chat-window"),
        messages: document.getElementById("ai-chat-messages"),
        input: document.getElementById("ai-chat-input"),
        sendBtn: document.getElementById("ai-chat-send"),
        status: container.querySelector("[data-ai-chat-target='status']"),
        statusBar: container.querySelector("[data-ai-chat-target='statusBar']"),
        periodPicker: document.getElementById("ai-chat-period-picker"),
      };

      this.bindEvents();
      container.setAttribute("aria-hidden", "false");

      // 从 localStorage 恢复对话历史
      this.restoreFromStorage();
    }

    // ========== Storage ==========

    storageKey() {
      return STORAGE_PREFIX + window.location.pathname;
    }

    saveToStorage() {
      try {
        const data = {
          conversationId: this.conversationId,
          messages: this.messagesData.slice(-MAX_STORED_MESSAGES),
          savedAt: Date.now()
        };
        localStorage.setItem(this.storageKey(), JSON.stringify(data));
      } catch (e) { /* ignore */ }
    }

    restoreFromStorage() {
      try {
        const raw = localStorage.getItem(this.storageKey());
        if (!raw) { this.showWelcomeMessage(); return; }

        const data = JSON.parse(raw);
        if (!data.messages || !Array.isArray(data.messages) || data.messages.length === 0) {
          this.showWelcomeMessage();
          return;
        }

        if (data.conversationId) {
          this.conversationId = data.conversationId;
        }

        this.messagesData = data.messages;
        this.rerenderAllMessages();
      } catch (e) {
        this.showWelcomeMessage();
      }
    }

    clearStorage() {
      try {
        localStorage.removeItem(this.storageKey());
      } catch (e) { /* ignore */ }
      this.messagesData = [];
    }

    // ========== Bind Events ==========

    bindEvents() {
      const { toggle, input, sendBtn, window: win } = this.elements;

      toggle.addEventListener("click", () => this.toggle());
      sendBtn.addEventListener("click", () => this.sendMessage());
      input.addEventListener("keydown", (e) => this.handleKeydown(e));
      input.addEventListener("input", () => this.autoResize());

      const closeBtn = win?.querySelector("[data-action*='toggle']");
      if (closeBtn) closeBtn.addEventListener("click", () => this.toggle());

      const newConvBtn = win?.querySelector("[data-action*='newConversation']");
      if (newConvBtn) newConvBtn.addEventListener("click", () => this.newConversation());

      // 报告按钮 — 点击后显示周期选择器
      const reportBtns = win?.querySelectorAll("[data-action*='pickPeriod']");
      reportBtns.forEach((btn) => {
        btn.addEventListener("click", (e) => this.pickPeriod(e));
      });

      // 周期选项按钮
      const { periodPicker } = this.elements;
      if (periodPicker) {
        periodPicker.querySelectorAll("[data-period-offset]").forEach((opt) => {
          opt.addEventListener("click", (e) => this.doGenerateReport(e));
        });
        // 点击外部关闭选择器
        document.addEventListener("click", (e) => {
          if (this.pendingReportType && !periodPicker.contains(e.target) &&
              !e.target.closest("[data-action*='pickPeriod']")) {
            this.hidePeriodPicker();
          }
        });
      }

      const quickBtns = win?.querySelectorAll("[data-action*='quickAsk']");
      quickBtns.forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const question = btn.dataset.question;
          if (question) { input.value = question; this.sendMessage(); }
        });
      });
    }

    // ========== Toggle ==========

    toggle() {
      const { toggle, window: win } = this.elements;
      const isOpen = !win.classList.contains("ai-chat-hidden");

      if (isOpen) {
        win.classList.add("ai-chat-hidden");
        win.style.display = "none";
        toggle.classList.remove("ai-chat-active");
        this.hidePeriodPicker();
      } else {
        win.classList.remove("ai-chat-hidden");
        win.style.display = "";
        toggle.classList.add("ai-chat-active");
        setTimeout(() => this.elements.input?.focus(), 300);
      }
    }

    // ========== Send Message ==========

    async sendMessage() {
      const { input } = this.elements;
      const message = input.value.trim();
      if (!message || this.isProcessing) return;

      input.value = "";
      input.style.height = "auto";
      this.setProcessing(true);
      this.appendMessage("user", message);

      try {
        const formData = new FormData();
        formData.append("message", message);
        formData.append("conversation_id", this.conversationId);

        const response = await fetch("/ai_assistant/chat/send_message", {
          method: "POST",
          headers: {
            "X-CSRF-Token": this.csrfToken,
            Accept: "application/json",
          },
          body: formData,
        });

        const data = await response.json();

        if (data.error) {
          this.appendMessage("assistant", "❌ " + data.error, true);
        } else {
          this.conversationId = data.conversation_id;
          this.appendMessage("assistant", data.message.content);
        }
      } catch (error) {
        this.appendMessage("assistant", "❌ 网络错误: " + error.message, true);
      } finally {
        this.setProcessing(false);
        this.scrollToBottom();
      }
    }

    // ========== Report Period Picker ==========

    /**
     * 显示周期选择器。用户点击报告按钮（日报/周报/月报）后展示两个周期选项。
     */
    pickPeriod(event) {
      if (this.isProcessing) return;

      const btn = event.currentTarget;
      const reportType = btn.dataset.reportType;
      const { periodPicker } = this.elements;
      if (!periodPicker) return;

      this.pendingReportType = reportType;

      // 更新选项按钮文字
      const opts = PERIOD_OPTIONS[reportType] || {};
      periodPicker.querySelectorAll("[data-period-offset]").forEach((opt) => {
        const offset = opt.dataset.periodOffset;
        opt.textContent = opts[offset] || opt.textContent;
      });

      // 高亮当前选中的按钮
      const allReportBtns = document.querySelectorAll("[data-action*='pickPeriod']");
      allReportBtns.forEach((b) => b.classList.remove("ai-chat-report-btn--active"));
      btn.classList.add("ai-chat-report-btn--active");

      periodPicker.style.display = "flex";
    }

    hidePeriodPicker() {
      this.pendingReportType = null;
      const { periodPicker } = this.elements;
      if (periodPicker) periodPicker.style.display = "none";

      // 取消高亮
      document.querySelectorAll(".ai-chat-report-btn--active")
        .forEach((b) => b.classList.remove("ai-chat-report-btn--active"));
    }

    /**
     * 用户选择具体周期（今日/昨日等）后，开始生成报告
     */
    async doGenerateReport(event) {
      const periodOffset = event.currentTarget.dataset.periodOffset;
      const reportType = this.pendingReportType;
      this.hidePeriodPicker();

      if (!reportType || this.isProcessing) return;

      const labels = { daily: "日报", weekly: "周报", monthly: "月报" };
      const periodNames = { "0": "当前", "-1": "上一" };
      this.setProcessing(true);
      this.appendMessage("user", "📝 生成" + (periodNames[periodOffset] || "") + (labels[reportType] || "报告") + "...");

      try {
        const formData = new FormData();
        formData.append("report_type", reportType);
        formData.append("period_offset", periodOffset);

        const response = await fetch("/ai_assistant/reports/generate", {
          method: "POST",
          headers: {
            "X-CSRF-Token": this.csrfToken,
            Accept: "application/json",
          },
          body: formData,
        });

        const data = await response.json();

        if (data.error) {
          this.appendMessage("assistant", "❌ " + data.error, true);
        } else {
          this.appendMessage("assistant", data.content);
        }
      } catch (error) {
        this.appendMessage("assistant", "❌ 报告生成失败: " + error.message, true);
      } finally {
        this.setProcessing(false);
        this.scrollToBottom();
      }
    }

    // ========== New Conversation ==========

    newConversation() {
      if (this.isProcessing) return;
      this.conversationId = this.generateId();
      this.clearStorage();
      const { messages } = this.elements;
      messages.innerHTML = "";
      this.showWelcomeMessage();
    }

    // ========== Keyboard ==========

    handleKeydown(event) {
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        this.sendMessage();
      }
    }

    autoResize() {
      const el = this.elements.input;
      el.style.height = "auto";
      el.style.height = Math.min(el.scrollHeight, 150) + "px";
    }

    // ========== Render / Append Message ==========

    appendMessage(role, content, isError) {
      isError = isError || false;
      const { messages } = this.elements;

      const welcome = messages.querySelector(".ai-chat-welcome");
      if (welcome) welcome.remove();

      this.messagesData.push({ role: role, content: content, isError: isError });
      this.renderSingleMessage({ role: role, content: content, isError: isError });
      this.saveToStorage();
      this.scrollToBottom();
    }

    rerenderAllMessages() {
      const { messages } = this.elements;
      messages.innerHTML = "";

      const oldWelcome = messages.querySelector(".ai-chat-welcome");
      if (oldWelcome) oldWelcome.remove();

      if (this.messagesData.length === 0) {
        this.showWelcomeMessage();
        return;
      }

      this.messagesData.forEach((msg) => {
        this.renderSingleMessage(msg);
      });
      this.scrollToBottom();
    }

    renderSingleMessage(msg) {
      const { messages } = this.elements;
      const div = document.createElement("div");
      div.className = "ai-chat-message ai-chat-" + msg.role + (msg.isError ? " ai-chat-error" : "");

      const avatar = msg.role === "user" ? "👤" : "🤖";
      const label  = msg.role === "user" ? "You" : "AI";
      const rendered = msg.isError ? this.escapeHtml(msg.content) : this.renderMarkdown(msg.content);

      div.innerHTML =
        '<div class="ai-chat-message-avatar">' + avatar + "</div>" +
        '<div class="ai-chat-message-body">' +
          '<div class="ai-chat-message-label">' + label + "</div>" +
          '<div class="ai-chat-message-content">' + rendered + "</div>" +
        "</div>";

      messages.appendChild(div);
    }

    // ========== Markdown + HTML 渲染器 ==========

    renderMarkdown(text) {
      if (!text || typeof text !== "string") return "";

      const codeBlocks = [];
      let processed = text.replace(/```(\w*)\n?([\s\S]*?)```/g, (_, lang, code) => {
        const idx = codeBlocks.length;
        codeBlocks.push({ type: "fence", lang: lang || "", code: code.trimEnd() });
        return "\x00FENCE" + idx + "\x00";
      });

      processed = processed.replace(/`([^`]+)`/g, (_, code) => {
        const idx = codeBlocks.length;
        codeBlocks.push({ type: "inline", code: code });
        return "\x00ICODE" + idx + "\x00";
      });

      processed = processed.replace(/(<\/?[a-zA-Z][^>]*>)/g, (tag) => {
        const idx = codeBlocks.length;
        codeBlocks.push({ type: "html", tag: tag });
        return "\x00HTML" + idx + "\x00";
      });

      processed = this.escapeHtml(processed);

      processed = processed.replace(/^[-*_]{3,}\s*$/gm, "<hr>");
      processed = this.renderTables(processed);

      processed = processed.replace(/^###### (.+)$/gm, "<h6>$1</h6>");
      processed = processed.replace(/^##### (.+)$/gm,  "<h5>$1</h5>");
      processed = processed.replace(/^#### (.+)$/gm,   "<h4>$1</h4>");
      processed = processed.replace(/^### (.+)$/gm,    "<h3>$1</h3>");
      processed = processed.replace(/^## (.+)$/gm,     "<h2>$1</h2>");
      processed = processed.replace(/^# (.+)$/gm,      "<h1>$1</h1>");

      // 引用块
      let lines = processed.split("\n");
      let result = [];
      let inBlockquote = false;
      let blockquoteLines = [];
      for (let i = 0; i <= lines.length; i++) {
        const line = i < lines.length ? lines[i] : "";
        const isBq = /^&gt; ?/.test(line);
        if (isBq) {
          if (!inBlockquote) inBlockquote = true;
          blockquoteLines.push(line.replace(/^&gt; ?/, ""));
        } else {
          if (inBlockquote) {
            result.push("<blockquote><p>" + blockquoteLines.join("<br>") + "</p></blockquote>");
            blockquoteLines = [];
            inBlockquote = false;
          }
          if (i < lines.length) result.push(line);
        }
      }
      processed = result.join("\n");

      processed = processed.replace(/^[\*-] (.+)$/gm, "<li>$1</li>");
      processed = processed.replace(/((?:<li>.*<\/li>\n?)+)/g, (match) => {
        if (/^<(?:ol|ul)>/.test(match.trim())) return match;
        return "<ul>\n" + match.trim() + "\n</ul>";
      });

      processed = processed.replace(/^\d+\.\s+(.+)$/gm, "<li>$1</li>");
      processed = processed.replace(/((?:<li>.*<\/li>\n?)+)/g, (match) => {
        if (/^<(?:ol|ul)>/.test(match.trim())) return match;
        return "<ol>\n" + match.trim() + "\n</ol>";
      });

      processed = processed.replace(/\n\n+/g, "</p><p>");
      processed = processed.replace(/\n/g, "<br>");
      processed = "<p>" + processed + "</p>";

      processed = processed.replace(/<p>\s*<\/p>/g, "");
      processed = processed.replace(/<p>(<(?:ul|ol|blockquote|h[1-6]|hr|table)>)/g, "$1");
      processed = processed.replace(/(<\/(?:ul|ol|blockquote|h[1-6]|table)>)\s*<\/p>/g, "$1");

      processed = processed.replace(/\*\*\*(.+?)\*\*\*/g, "<strong><em>$1</em></strong>");
      processed = processed.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
      processed = processed.replace(/\*(.+?)\*/g, "<em>$1</em>");
      processed = processed.replace(/~~(.+?)~~/g, "<del>$1</del>");
      processed = processed.replace(/\[([^\]]+)\]\(([^)]+)\)/g,
        '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');
      processed = processed.replace(/!\[([^\]]*)\]\(([^)]+)\)/g,
        '<img src="$2" alt="$1" style="max-width:100%">');

      processed = processed.replace(/\x00FENCE(\d+)\x00/g, (_, idx) => {
        const item = codeBlocks[parseInt(idx)];
        if (!item) return "";
        const langAttr = item.lang ? ' class="language-' + this.escapeHtml(item.lang) + '"' : "";
        return "<pre><code" + langAttr + ">" + this.escapeHtml(item.code).replace(/\n/g, "<br>") + "</code></pre>";
      });

      processed = processed.replace(/\x00ICODE(\d+)\x00/g, (_, idx) => {
        const item = codeBlocks[parseInt(idx)];
        return item ? "<code>" + this.escapeHtml(item.code) + "</code>" : "";
      });

      processed = processed.replace(/\x00HTML(\d+)\x00/g, (_, idx) => {
        const item = codeBlocks[parseInt(idx)];
        if (!item) return "";
        return this.sanitizeHtmlTag(item.tag);
      });

      return processed;
    }

    renderTables(text) {
      const lines = text.split("\n");
      const result = [];
      let tableLines = [];
      let inTable = false;

      for (let i = 0; i <= lines.length; i++) {
        const line = i < lines.length ? lines[i] : "";
        const isTableRow = /^\|.+\|$/.test(line.trim());
        if (isTableRow) {
          if (!inTable) inTable = true;
          tableLines.push(line.trim());
        } else {
          if (inTable) {
            result.push(this.buildTableHtml(tableLines));
            tableLines = [];
            inTable = false;
          }
          if (i < lines.length) result.push(line);
        }
      }
      return result.join("\n");
    }

    buildTableHtml(tableLines) {
      if (tableLines.length < 2) return tableLines.join("\n");
      let html = "<table>";
      let isHeader = true;

      for (let i = 0; i < tableLines.length; i++) {
        const cells = tableLines[i]
          .replace(/^\||\|$/g, "")
          .split("|")
          .map((c) => c.trim());

        if (/^[-:\s]+$/.test(cells.join(""))) {
          isHeader = false;
          continue;
        }

        const tag = isHeader ? "th" : "td";
        html += "<tr>";
        cells.forEach((cell) => {
          html += "<" + tag + ">" + cell + "</" + tag + ">";
        });
        html += "</tr>";
        isHeader = false;
      }

      html += "</table>";
      return html;
    }

    sanitizeHtmlTag(tag) {
      const lower = tag.toLowerCase();
      const dangerous = ["script", "iframe", "object", "embed", "form", "input",
                         "link", "style", "meta", "base", "applet", "frame", "frameset"];
      const tagName = (lower.match(/<\/?([a-zA-Z][a-zA-Z0-9]*)/) || [])[1];
      if (tagName && dangerous.includes(tagName)) return "";
      return tag.replace(/\s+on\w+\s*=\s*"[^"]*"/gi, "")
                .replace(/\s+on\w+\s*=\s*'[^']*'/gi, "")
                .replace(/javascript\s*:/gi, "");
    }

    // ========== Helpers ==========

    escapeHtml(text) {
      return String(text)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    }

    showWelcomeMessage() {
      const { messages } = this.elements;
      const div = document.createElement("div");
      div.className = "ai-chat-welcome";
      div.innerHTML =
        '<div class="ai-chat-welcome-icon">🤖</div>' +
        "<p>你好！我是 AI 助手。有什么可以帮你的？</p>" +
        '<p class="ai-chat-disclaimer">⚠️ 涉及业务数据时，我处于只读模式</p>';
      messages.appendChild(div);
    }

    setProcessing(processing) {
      this.isProcessing = processing;
      const { sendBtn, statusBar, status } = this.elements;

      if (processing) {
        sendBtn.disabled = true;
        if (statusBar) statusBar.style.display = "flex";
        if (status) status.textContent = "🟡";
      } else {
        sendBtn.disabled = false;
        if (statusBar) statusBar.style.display = "none";
        if (status) status.textContent = "🟢";
      }
    }

    scrollToBottom() {
      setTimeout(() => {
        const { messages } = this.elements;
        if (messages) messages.scrollTop = messages.scrollHeight;
      }, 50);
    }

    generateId() {
      return "conv_" + Date.now() + "_" + Math.random().toString(36).substring(2, 10);
    }
  }

  // ========== 初始化 ==========
  document.addEventListener("DOMContentLoaded", function () {
    window.aiChatWidget = new AIChatWidget();
  });

  document.addEventListener("turbo:load", function () {
    if (!window.aiChatWidget || !document.getElementById("ai-chat-widget")) {
      window.aiChatWidget = new AIChatWidget();
    }
  });
})();
