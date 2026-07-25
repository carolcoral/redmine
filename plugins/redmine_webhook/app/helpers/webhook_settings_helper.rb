module WebhookSettingsHelper
  def default_template(status)
    case status.name.downcase
    when /new|新建/
      "${user} 创建了任务 ${task}，项目：${project}，详情：${url}"
    when /in progress|进行中/
      "任务 ${task} 状态更新为 ${status}，操作人：${user}，详情：${url}"
    when /resolved|已解决/
      "${user} 已解决任务 ${task}，详情：${url}"
    when /closed|已关闭/
      "任务 ${task} 已关闭，操作人：${user}，详情：${url}"
    when /rejected|已拒绝/
      "任务 ${task} 已被拒绝，操作人：${user}，详情：${url}"
    else
      "任务 ${task} 状态更新为 ${status}，操作人：${user}，详情：${url}"
    end
  end
end