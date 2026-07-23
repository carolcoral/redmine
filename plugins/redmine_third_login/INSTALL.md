# Redmine Third Login Plugin 安装指南

## 快速安装

### 1. 进入插件目录

```bash
cd /path/to/redmine/plugins
```

### 2. 下载插件

```bash
git clone https://github.com/carolcoral/redmine_third_login.git
```

或者下载zip包并解压：

```bash
wget https://github.com/carolcoral/redmine_third_login/archive/main.zip
unzip main.zip
mv redmine_third_login-main redmine_third_login
```

### 3. 安装依赖

```bash
cd /path/to/redmine
bundle install
```

### 4. 重启Redmine

根据你的部署方式：

**对于Passenger：**
```bash
touch tmp/restart.txt
```

**对于Puma（systemd）：**
```bash
sudo systemctl restart redmine
```

**对于Docker：**
```bash
docker-compose restart
```

### 5. 配置插件

1. 登录Redmine管理员账户
2. 进入 **管理 → 插件**
3. 找到 **Redmine Third Login Plugin**
4. 点击 **配置**
5. 根据下方说明填写配置信息

## 详细安装步骤

### 环境要求确认

确保你的环境满足以下要求：

- Redmine 6.1.1 或更高版本
- Ruby 3.0+
- Rails 6.1+
- 网络可以访问钉钉开放平台

### 预安装检查

```bash
# 检查Redmine版本
cd /path/to/redmine
bundle exec rake about

# 确保插件目录存在
ls -la plugins/
```

### 插件安装

```bash
# 进入插件目录
cd plugins

# 克隆插件代码
git clone https://github.com/carolcoral/redmine_third_login.git

# 返回Redmine根目录
cd ..

# 安装gem依赖
bundle install --without development test

# 如果需要，执行数据库迁移
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

### 权限设置

```bash
# 确保插件目录权限正确
chown -R redmine:redmine plugins/redmine_third_login
chmod -R 755 plugins/redmine_third_login
```

### 服务重启

重启Redmine服务以使插件生效：

```bash
# Passenger
touch tmp/restart.txt

# Apache
sudo systemctl restart apache2

# Nginx + Passenger
sudo systemctl restart nginx

# 检查日志是否有错误
tail -f log/production.log | grep -i error
```

## 配置指南

### 钉钉开放平台配置

1. **登录钉钉开放平台**
   - 访问 https://open.dingtalk.com/
   - 使用企业管理员账号登录

2. **创建应用**
   - 点击"应用开发" → "企业内部应用" → "创建应用"
   - 填写应用名称和描述
   - 选择应用类型为"H5微应用"

3. **获取凭证**
   - 在应用详情页找到 **AppKey** 和 **AppSecret**
   - 这些值将用于插件配置

4. **配置权限**
   - 进入"权限管理"页面
   - 添加以下权限：
     - `企业员工手机号信息`
     - `通讯录部门信息读权限`
     - `成员信息读权限`
     - `企业内部应用免登`

5. **配置回调域名**
   - 进入"登录与分享"配置
   - 添加回调域名：你的Redmine域名（如 `redmine.yourcompany.com`）
   - 确保域名已备案且可访问

### 插件配置

1. **进入配置页面**
   - 登录Redmine管理员账号
   - 导航到 **管理 → 插件**
   - 点击 **Redmine Third Login Plugin** 的"配置"按钮

2. **填写钉钉配置**
   ```
   App ID: 填写钉钉应用的 AppKey
   App Secret: 填写钉钉应用的 AppSecret
   ```

3. **选择登录方式**
   - 勾选需要启用的登录方式
   - 至少启用一种登录方式

4. **保存配置**
   - 点击"应用"按钮保存设置

### 手机号字段配置

**重要**：插件通过手机号匹配用户，必须配置手机号字段。

1. **创建自定义字段**
   - 进入 **管理 → 自定义字段**
   - 点击"新建自定义字段"
   - 类型选择 **文本**
   - 名称填写 **手机号**（必须完全一致）
   - 应用于 **用户**
   - 保存

2. **为用户添加手机号**
   - 进入 **管理 → 用户**
   - 编辑每个用户
   - 在自定义字段中填写手机号
   - 手机号必须与钉钉账号绑定的手机号一致

### LDAP配置（可选）

如需使用LDAP登录：

1. **配置LDAP认证源**
   - 进入 **管理 → LDAP认证**
   - 点击"新建LDAP认证"
   - 填写LDAP服务器信息
   - 测试连接并保存

2. **启用LDAP登录**
   - 在插件配置中勾选"LDAP登录"
   - 确保至少有一个LDAP认证源可用

## 验证安装

### 1. 检查插件是否加载

访问Redmine，在登录页面应该看到：
- 登录方式选择器（如果启用多种方式）
- 钉钉登录二维码（如果启用钉钉登录）

### 2. 测试各种登录方式

**本地登录测试：**
- 选择"本地登录"
- 使用Redmine本地账号登录
- 验证是否可以正常登录

**LDAP登录测试（如启用）：**
- 选择"LDAP登录"
- 使用LDAP账号登录
- 验证是否可以正常登录

**钉钉登录测试（如启用）：**
- 选择"钉钉扫码登录"
- 使用钉钉扫描二维码
- 确认登录
- 验证是否自动登录成功

### 3. 检查日志

```bash
# 查看插件相关日志
tail -f log/production.log | grep "RedmineThirdLogin"

# 应该看到类似信息：
# [RedmineThirdLogin] Plugin initialized successfully
# [RedmineThirdLogin] DingTalk login enabled: true
```

## 升级插件

### 备份配置

```bash
# 备份插件配置
mkdir -p /backup/redmine_plugins
cp -r plugins/redmine_third_login /backup/redmine_plugins/redmine_third_login_$(date +%Y%m%d)
```

### 升级步骤

```bash
# 进入插件目录
cd plugins/redmine_third_login

# 拉取最新代码
git pull origin main

# 或者下载新版本并解压覆盖

# 安装新的依赖
cd /path/to/redmine
bundle install

# 重启服务
touch tmp/restart.txt
```

## 卸载插件

### 1. 移除插件目录

```bash
cd /path/to/redmine/plugins
rm -rf redmine_third_login
```

### 2. 清理数据库（如果需要）

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate NAME=redmine_third_login VERSION=0 RAILS_ENV=production
```

### 3. 清理配置

```bash
# 删除插件设置
bundle exec rails runner "Setting.plugin_redmine_third_login = nil" -e production
```

### 4. 重启服务

```bash
touch tmp/restart.txt
```

## 故障排查

### 插件无法加载

**症状**: 插件列表中看不到插件

**解决**:
```bash
# 检查插件目录结构
ls -la plugins/redmine_third_login/

# 确保init.rb存在
ls -la plugins/redmine_third_login/init.rb

# 检查Redmine日志
grep -i "redmine_third_login" log/production.log

# 重新执行bundle install
bundle install

# 重启服务
```

### 钉钉配置无效

**症状**: 配置保存后无法生成二维码

**解决**:
```bash
# 检查配置是否正确保存
cat log/production.log | grep "dingtalk"

# 验证AppID和AppSecret
curl -s "https://oapi.dingtalk.com/gettoken?appkey=YOUR_APPID&appsecret=YOUR_APPSECRET"

# 检查网络连接
telnet oapi.dingtalk.com 443
```

### 用户匹配失败

**症状**: 扫码后提示"未找到匹配的Redmine用户"

**解决**:
1. 检查用户是否有手机号字段
2. 确认手机号与钉钉一致
3. 查看日志确认匹配过程:
   ```bash
   tail -f log/production.log | grep "mobile"
   ```

### 样式加载失败

**症状**: 页面样式错乱

**解决**:
```bash
# 清除缓存
rm -rf tmp/cache

# 确保静态文件存在
ls -la plugins/redmine_third_login/assets/stylesheets/
ls -la plugins/redmine_third_login/assets/javascripts/

# 检查文件权限
chmod -R 644 plugins/redmine_third_login/assets/*
```

## 获取帮助

- **GitHub Issues**: [提交Issue](https://github.com/carolcoral/redmine_third_login/issues)
- **项目文档**: [查看完整文档](https://github.com/carolcoral/redmine_third_login)
- **钉钉文档**: [钉钉开放平台](https://open.dingtalk.com/)

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

---

**作者**: carolcoral  
**GitHub**: [https://github.com/carolcoral](https://github.com/carolcoral)  
**项目地址**: [https://github.com/carolcoral/redmine_third_login](https://github.com/carolcoral/redmine_third_login)
