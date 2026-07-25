# This file is a part of Redmine Q&A (redmine_questions) plugin,
# Q&A plugin for Redmine
#
# Copyright (C) 2011-2025 RedmineUP
# http://www.redmineup.com/
#
# redmine_questions is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_questions is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_questions.  If not, see <http://www.gnu.org/licenses/>.

module RedmineQuestions
end

REDMINE_QUESTIONS_REQUIRED_FILES = [
  'redmine_questions/hooks/views_layouts_hook',
  'redmine_questions/patches/user_patch',
  'redmine_questions/patches/project_patch',
  'redmine_questions/patches/notifiable_patch',
  'redmine_questions/patches/mailer_patch',
  'redmine_questions/patches/projects_helper_patch',
  'redmine_questions/patches/auto_completes_controller_patch',
  'redmine_questions/patches/comment_patch',
  'acts_as_attachable_questions/init'
]

base_url = File.dirname(__FILE__)
REDMINE_QUESTIONS_REQUIRED_FILES.each { |file| require(base_url + '/' + file) }
