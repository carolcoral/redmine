# 功能问题排查指南 - 双击和拖拽不工作

## 问题描述

1. **双击日期空白区域**无法创建新任务
2. **拖拽任务**无法修改创建日期
3. 只有**右键菜单**正常工作

## 原因分析

JavaScript 功能依赖以下条件：
1. 日历日期单元格必须有 `data-date` 属性
2. 日期单元格必须有 `calendar-day` CSS 类
3. 任务元素必须有 `calendar-issue` CSS 类
4. 所有必要的 JavaScript 文件必须正确加载

## 排查步骤

### 1. 检查浏览器控制台

打开浏览器开发者工具（F12），查看 Console 标签：

```javascript
// 应该看到以下日志：
"Redmine Calendar Plugin: Initializing..."
"Redmine Calendar Plugin: Data loaded" 
"Redmine Calendar Plugin: Initialized day cell 2026-02-03"
"Redmine Calendar Plugin: Initialized issue 123"
"Redmine Calendar Plugin: Initialization complete"

// 自动运行的测试：
"=== Redmine Calendar Plugin Debug Tests ==="
"1. Calendar data element exists: ✓ PASS"
"2. Calendar days with data-date attribute: ✓ PASS"
"3. Enhanced calendar issues: ✓ PASS"
"4. JavaScript libraries loaded: ✓ PASS"
```

**如果没有看到这些日志**，说明 JavaScript 没有正确加载或执行。

### 2. 检查 DOM 元素

在 Console 中运行以下命令：

```javascript
// 检查日历数据
$('#redmine-calendar-data').length  // 应该返回 1
$('#redmine-calendar-data').data()   // 应该返回对象数据

// 检查日期单元格
$('.calendar-day').length  // 应该大于 0
$('.calendar-day').first().data('date')  // 应该返回日期字符串如 "2026-02-03"

// 检查任务元素
$('.calendar-issue').length  // 应该大于 0
$('.calendar-issue').first().data('issue-id')  // 应该返回数字
$('.calendar-issue').first().attr('draggable')  // 应该返回 "true"

// 检查事件监听器
RedmineCalendarDebug.checkEventListeners()
```

### 3. 手动测试功能

在 Console 中运行：

```javascriptn// 手动触发双击测试（替换为实际日期）
RedmineCalendarDebug.testDoubleClick('2026-02-03')

// 手动测试拖拽功能
var testIssue = $('.calendar-issue').first()
console.log('Test issue:', testIssue.data('issue-id'))
```

### 4. 检查 JavaScript 错误

在 Console 中查看是否有错误信息：
- `TypeError: Cannot read property 'xxx' of undefined`
- `ReferenceError: xxx is not defined`
- `404 Not Found` (资源加载失败)

### 5. 检查网络请求

在 Network 标签中：
1. 刷新页面
2. 检查以下文件是否成功加载（Status 200）：
   - `redmine_calendar.js`
   - `redmine_calendar_debug.js`
   - `redmine_calendar.css`

## 常见问题及解决方案

### 问题1：JavaScript 文件未加载

**现象**：Console 中没有插件日志

**解决方案**：
1. 检查 `app/views/hooks/redmine_calendar/_view_calendars_show_bottom.html.erb` 是否存在
2. 检查钩子是否正确注册
3. 重启 Redmine：
   ```bash
   touch tmp/restart.txt
   ```

### 问题2：日期单元格没有 data-date 属性

**现象**：`$('.calendar-day').first().data('date')` 返回 undefined

**解决方案**：
1. 检查日历 DOM 结构
2. 在 Console 中运行：
   ```javascript
   $('.calendar td').first().find('a').attr('href')
   ```
3. 检查是否有日期参数在 URL 中

### 问题3：任务元素没有增强

**现象**：`$('.calendar-issue')` 返回空数组

**解决方案**：
1. 检查任务元素选择器是否正确
2. 在 Console 中运行：
   ```javascript
   $('.calendar .issue').length  // 应该返回大于 0
   ```
3. 如果没有，检查日历是否真的有任务显示

### 问题4：事件监听器未绑定

**现象**：双击和拖拽无响应，但右键菜单工作

**解决方案**：
1. 检查 Redmine 日历的 HTML 结构
2. 确认选择器 `.calendar-day` 和 `.calendar-issue` 匹配实际元素
3. 修改选择器以匹配实际结构

### 问题5：AJAX 请求失败

**现象**：创建问题或拖拽时显示错误

**解决方案**：
1. 检查路由配置：`config/routes.rb`
2. 检查 Controller：`app/controllers/redmine_calendar_controller.rb`
3. 检查权限：用户是否有 `edit_calendar_issues` 权限
4. 查看 Network 标签中的请求详情

## 调试技巧

### 添加断点调试

在 Chrome/Firefox 中：
1. 打开 Sources 标签
2. 找到 `redmine_calendar.js`
3. 在以下位置添加断点：
   - `setupDoubleClick` 函数
   - `setupDragAndDrop` 函数
   - 事件处理函数

### 检查 Redmine 版本差异

不同 Redmine 版本的日历 HTML 结构可能不同：

**Redmine 6.x 常见结构**：
```html
<table class="calendar">
  <tr>
    <td>  <!-- 日期单元格 -->
      <p class="day-number">3</p>
      <a href="/projects/test/activity?from=2026-02-03">...</a>
      <div class="issue">...</div>
    </td>
  </tr>
</table>
```

如果结构不同，需要调整选择器。

### 强制重新初始化

在 Console 中手动触发初始化：

```javascript
// 重新初始化日期单元格
$('.calendar td').each(function() {
  var $td = $(this);
  var href = $td.find('a').attr('href');
  if (href && href.match(/from=([0-9]{4}-[0-9]{2}-[0-9]{2})/)) {
    var date = href.match(/from=([0-9]{4}-[0-9]{2}-[0-9]{2})/)[1];
    $td.addClass('calendar-day').attr('data-date', date);
  }
});

// 重新初始化任务
$('.calendar .issue').each(function() {
  var $issue = $(this);
  var issueId = $issue.attr('id').replace('issue-', '');
  $issue.addClass('calendar-issue')
        .attr('data-issue-id', issueId)
        .attr('draggable', 'true');
});
```

## 如果仍然无法工作

1. **提供以下信息**：
   - Redmine 版本号
   - 浏览器 Console 日志（完整）
   - 浏览器 Console 中运行以下命令的结果：
     ```javascript
     console.log('Redmine version:', window.Redmine || 'unknown')
     console.log('jQuery version:', $.fn.jquery)
     console.log('Calendar HTML:', $('.calendar').first().html())
     ```

2. **临时解决方案**：
   修改 `assets/javascripts/redmine_calendar.js`，调整选择器以匹配实际的 HTML 结构

3. **回退方案**：
   如果插件仍然无法工作，考虑禁用增强功能，仅使用内置日历

## 联系方式

如果以上步骤都无法解决问题，请提供：
1. 完整的浏览器 Console 日志
2. 日历页面的 HTML 源代码（查看源代码）
3. Redmine 版本信息
4. 浏览器版本信息
5. 插件版本信息