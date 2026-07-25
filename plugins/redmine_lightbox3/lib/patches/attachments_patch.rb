# redmine_lightbox3/lib/patches/attachments_patch.rb
# Redmine 6 / Rails 8 兼容：用 prepend 替代 alias_method_chain

module Patches
  module AttachmentsPatch
    # 在附件連結中新增 css class "lightbox"
    def link_to_attachment(options = {})
      super(options)
        .gsub('>')
        .gsub('</a>', ' class="lightbox"></a>')
    end
  end
end
