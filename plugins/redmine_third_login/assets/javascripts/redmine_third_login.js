// Redmine Third Login Plugin JavaScript
// 作者: carolcoral

(function() {
  'use strict';

  // 钉钉二维码实例
  let dingtalkQRCode = null;

  /**
   * 生成钉钉登录二维码
   */
  window.generateDingtalkQRCode = function() {
    const container = document.getElementById('dingtalk-qr-code');
    const status = document.getElementById('dingtalk-login-status');
    
    if (!container) {
      console.error('钉钉二维码容器未找到');
      return;
    }

    // 清空容器和状态
    container.innerHTML = '';
    if (status) status.innerHTML = '';

    // 获取钉钉配置
    const config = window.dingtalkConfig || {};
    if (!config.appid) {
      showDingtalkError('钉钉应用ID未配置');
      return;
    }

    // 显示加载状态
    showDingtalkStatus('正在生成登录二维码...');

    // 生成唯一的state参数
    const state = generateRandomState();
    
    // 构建钉钉扫码登录URL
    const redirectUri = encodeURIComponent(window.location.origin + '/dingtalk_login/callback');
    const qrCodeUrl = `https://oapi.dingtalk.com/connect/oauth2/sns_authorize?appid=${config.appid}&response_type=code&scope=snsapi_login&state=${state}&redirect_uri=${redirectUri}`;
    
    // 生成二维码
    generateQRCode(container, qrCodeUrl, function(error) {
      if (error) {
        showDingtalkError('二维码生成失败: ' + error);
      } else {
        showDingtalkStatus('请使用钉钉扫描二维码登录');
        // 开始轮询登录状态
        startLoginPolling(state);
      }
    });
  };

  /**
   * 生成二维码（简化版本，不依赖外部库）
   * 使用Google Charts API生成二维码图片
   */
  function generateQRCode(container, url, callback) {
    try {
      // 使用Google Charts API生成二维码图片
      const qrApiUrl = `https://chart.googleapis.com/chart?chs=200x200&cht=qr&chl=${encodeURIComponent(url)}&choe=UTF-8`;
      
      container.innerHTML = `<img src="${qrApiUrl}" alt="钉钉登录二维码" style="width: 100%; height: 100%;"/>`;
      
      if (callback) callback(null);
    } catch (error) {
      // 如果失败，显示链接作为备选方案
      container.innerHTML = `<a href="${url}" target="_blank" class="dingtalk-login-link">点击此处打开钉钉登录</a>`;
      if (callback) callback(error.message);
    }
  }

  /**
   * 生成随机state参数
   */
  function generateRandomState() {
    const array = new Uint8Array(16);
    crypto.getRandomValues(array);
    return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
  }

  /**
   * 显示钉钉登录状态
   */
  function showDingtalkStatus(message) {
    const status = document.getElementById('dingtalk-login-status');
    if (status) {
      status.className = 'dingtalk-login-status info';
      status.textContent = message;
    }
  }

  /**
   * 显示钉钉登录错误
   */
  function showDingtalkError(message) {
    const status = document.getElementById('dingtalk-login-status');
    if (status) {
      status.className = 'dingtalk-login-status error';
      status.textContent = message;
    }
    console.error('[RedmineThirdLogin] ' + message);
  }

  /**
   * 开始轮询登录状态
   */
  function startLoginPolling(state) {
    // 这里可以实现轮询逻辑，检查用户是否已完成扫码
    // 由于钉钉通常使用回调方式，这里主要是显示状态
    console.log('[RedmineThirdLogin] Started login polling for state:', state);
  }

  /**
   * 处理登录方式切换
   */
  function handleLoginTypeChange(loginType) {
    const usernameField = document.querySelector('#username');
    const passwordField = document.querySelector('#password');
    const ldapField = document.querySelector('#ldap-auth-source');
    const dingtalkContainer = document.getElementById('dingtalk-login-container');
    const loginSubmit = document.querySelector('input[type="submit"]');
    const rememberMe = document.querySelector('#autologin');
    const loginForm = document.querySelector('#login-form');

    // 隐藏所有字段
    if (usernameField) usernameField.closest('p').style.display = 'none';
    if (passwordField) passwordField.closest('p').style.display = 'none';
    if (ldapField) ldapField.closest('p').style.display = 'none';
    if (dingtalkContainer) dingtalkContainer.style.display = 'none';
    if (loginSubmit) loginSubmit.style.display = 'none';
    if (rememberMe) rememberMe.closest('p').style.display = 'none';

    // 根据登录类型显示相应字段
    switch(loginType) {
      case 'local':
      case 'ldap':
        if (usernameField) usernameField.closest('p').style.display = 'block';
        if (passwordField) passwordField.closest('p').style.display = 'block';
        if (loginSubmit) loginSubmit.style.display = 'block';
        if (rememberMe) rememberMe.closest('p').style.display = 'block';
        
        if (loginType === 'ldap' && ldapField) {
          ldapField.closest('p').style.display = 'block';
        }
        
        // 更新表单action
        if (loginForm) {
          loginForm.action = '/login';
        }
        break;
        
      case 'dingtalk':
        if (dingtalkContainer) {
          dingtalkContainer.style.display = 'block';
          // 生成二维码
          setTimeout(function() {
            if (typeof generateDingtalkQRCode === 'function') {
              generateDingtalkQRCode();
            }
          }, 100);
        }
        break;
    }
  }

  /**
   * 初始化登录方式选择器
   */
  function initLoginTypeSelector() {
    const loginTypeSelect = document.getElementById('login-type-select');
    if (loginTypeSelect) {
      // 绑定事件处理
      loginTypeSelect.addEventListener('change', function() {
        handleLoginTypeChange(this.value);
      });
      
      // 初始化显示
      handleLoginTypeChange(loginTypeSelect.value);
    }
  }

  /**
   * 检查依赖库是否加载
   */
  function checkDependencies() {
    const missingDeps = [];
    
    if (typeof QRCode === 'undefined') {
      missingDeps.push('QRCode.js');
    }
    
    if (missingDeps.length > 0) {
      console.warn('[RedmineThirdLogin] Missing dependencies: ' + missingDeps.join(', '));
    }
  }

  // 页面加载完成后初始化
  document.addEventListener('DOMContentLoaded', function() {
    checkDependencies();
    initLoginTypeSelector();
    
    // 暴露全局变量供其他脚本使用
    window.RedmineThirdLogin = {
      generateDingtalkQRCode: window.generateDingtalkQRCode,
      handleLoginTypeChange: handleLoginTypeChange
    };
  });

  // 处理AJAX错误
  document.addEventListener('ajax:error', function(event) {
    const detail = event.detail;
    const xhr = detail[2];
    
    if (xhr && xhr.status >= 400) {
      console.error('[RedmineThirdLogin] AJAX error:', xhr.status, xhr.responseText);
    }
  });

})();