#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "user asset accesses" do
  before(:each) do
    Setting.set('enable_page_views', 'db')

    username = "nobody@example.com"
    password = "asdfasdf"
    u = user_with_pseudonym :active_user => true,
                            :username => username,
                            :password => password
    u.save!
    @e = course_with_teacher :active_course => true,
                            :user => u,
                            :active_enrollment => true
    @e.save!
    @teacher = u
    user_session(@user, @pseudonym)

    user_model
    @student = @user
    @course.enroll_student(@student).accept
  end

  include ApplicationHelper

  it "should record and show user asset accesses" do
    now = Time.now.utc
    Time.stubs(:now).returns(now)

    assignment = @course.assignments.create(:title => 'Assignment 1')
    assignment.workflow_state = 'active'
    assignment.save!

    user_session(@student)
    get "/courses/#{@course.id}/assignments/#{assignment.id}"
    response.should be_success

    user_session(@teacher)
    get "/courses/#{@course.id}/users/#{@student.id}/usage"
    response.should be_success
    html = Nokogiri::HTML(response.body)
    html.css('#usage_report .access.assignment').length.should == 1
    html.css('#usage_report .access.assignment .readable_name').text.strip.should == 'Assignment 1'
    html.css('#usage_report .access.assignment .view_score').text.strip.should == '1'
    html.css('#usage_report .access.assignment .last_viewed').text.strip.should == datetime_string(now)
    AssetUserAccess.where(:user_id => @student).first.last_access.to_i.should == now.to_i

    now2 = now + 1.hour
    Time.stubs(:now).returns(now2)

    # make sure that we're not using the uodated_at time as the time of the access
    AssetUserAccess.where(:user_id => @student).update_all(:updated_at => now2 + 5.hours)

    user_session(@student)
    get "/courses/#{@course.id}/assignments/#{assignment.id}"
    response.should be_success

    user_session(@teacher)
    get "/courses/#{@course.id}/users/#{@student.id}/usage"
    response.should be_success
    html = Nokogiri::HTML(response.body)
    html.css('#usage_report .access.assignment').length.should == 1
    html.css('#usage_report .access.assignment .readable_name').text.strip.should == 'Assignment 1'
    html.css('#usage_report .access.assignment .view_score').text.strip.should == '2'
    html.css('#usage_report .access.assignment .last_viewed').text.strip.should == datetime_string(now2)
    AssetUserAccess.where(:user_id => @student).first.last_access.to_i.should == now2.to_i
  end
end
