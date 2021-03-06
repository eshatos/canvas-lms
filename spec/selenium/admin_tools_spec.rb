require File.expand_path(File.dirname(__FILE__) + '/common')
require File.expand_path(File.dirname(__FILE__) + '/helpers/calendar2_common')
require File.expand_path(File.dirname(__FILE__) + '/../cassandra_spec_helper')

describe "admin_tools" do
  include_examples "in-process server selenium tests"

  def load_admin_tools_page
    get "/accounts/#{@account.id}/admin_tools"
    wait_for_ajaximations
  end

  def perform_user_search(form_sel, search_term, click_row = 0)
    set_value f("#{form_sel} input[name=search_term]"), search_term
    sleep 0.2 # 0.2 s delay before the search fires
    wait_for_ajaximations
    fj("#{form_sel} .roster tbody tr:nth(#{click_row}) td").click
  end

  def perform_autocomplete_search(field_sel, search_term, click_row = 0)
    set_value f(field_sel), search_term
    sleep 0.5
    wait_for_ajaximations
    fj(".ui-autocomplete.ui-menu > .ui-menu-item:nth(#{click_row}) > a").click
  end

  def setup_users
    # Setup a student (@student)
    course_with_student(:active_all => true, :account => @account, :user => user_with_pseudonym(:name => 'Student TestUser'))
    user_with_pseudonym(:user => @student, :account => @account)

    setup_account_admin
  end

  def setup_account_admin(permissions = {:view_notifications => true})
    # Setup an account admin (@account_admin) and logged in.
    account_admin_user_with_role_changes(:account => @account, :role_changes => permissions)
    @account_admin = @admin
    user_with_pseudonym(:user => @account_admin, :account => @account)
    user_session(@account_admin)
  end

  def click_view_tab(tab_name)
    wait_for_ajaximations
    tab = fj("#adminToolsTabs .#{tab_name} > a")
    tab.should_not be_nil
    tab.should be_displayed
    tab.click
    wait_for_ajaximations
  end

  def change_log_type(log_type)
    wait_for_ajaximations
    click_option("#loggingType", "\#logging#{log_type}", :value)
    wait_for_ajaximations
  end

  before do
    @account = Account.default
    setup_users
  end

  context "View Notifications" do
    before :each do
      @account.settings[:admins_can_view_notifications] = true
      @account.save!
    end

    def click_view_notifications_tab
      click_view_tab("notifications")
    end

    context "as SiteAdmin" do
      it "should perform search without account setting or user permission" do
        @account.settings[:admins_can_view_notifications] = false
        @account.save!
        site_admin_user
        user_with_pseudonym(:user => @admin, :account => @account)
        user_session(@admin)
        message(:user_id => @student.id, :body => 'this is my message', :account_id => @account.id)

        load_admin_tools_page
        click_view_notifications_tab
        perform_user_search("#commMessagesSearchForm", @student.id)
        f('#commMessagesSearchForm .userDateRangeSearchBtn').click
        wait_for_ajaximations
        f('#commMessagesSearchResults .message-body').text.should contain('this is my message')
      end
    end

    context "as AccountAdmin" do
      context "with permissions" do
        it "should perform search" do
          message(:user_id => @student.id)
          load_admin_tools_page
          click_view_notifications_tab
          perform_user_search("#commMessagesSearchForm", @student.id)
          f('#commMessagesSearchForm .userDateRangeSearchBtn').click
          wait_for_ajaximations
          f('#commMessagesSearchResults .message-body').text.should contain('nice body')
        end

        it "should display nothing found" do
          message(:user_id => @student.id)
          load_admin_tools_page
          click_view_notifications_tab
          perform_user_search("#commMessagesSearchForm", @student.id)
          set_value f('#commMessagesSearchForm .dateEndSearchField'), 2.months.ago
          f('#commMessagesSearchForm .userDateRangeSearchBtn').click
          wait_for_ajaximations
          f('#commMessagesSearchResults .alert').text.should contain('No messages found')
          f('#commMessagesSearchResults .message-body').should be_nil
        end

        it "should display valid search params used" do
          message(:user_id => @student.id)
          load_admin_tools_page
          click_view_notifications_tab
          # Search with no dates
          perform_user_search("#commMessagesSearchForm", @student.id)
          f('#commMessagesSearchForm .userDateRangeSearchBtn').click
          wait_for_ajaximations
          f('#commMessagesSearchOverview').text.should contain("Notifications sent to #{@student.name} from the beginning to now.")
          # Search with begin date and end date - should show time actually being used
          perform_user_search("#commMessagesSearchForm", @student.id)
          set_value f('#commMessagesSearchForm .dateStartSearchField'), 'Mar 3, 2001'
          set_value f('#commMessagesSearchForm .dateEndSearchField'), 'Mar 9, 2001'
          f('#commMessagesSearchForm .userDateRangeSearchBtn').click
          wait_for_ajaximations
          f('#commMessagesSearchOverview').text.should contain("Notifications sent to #{@student.name} from Mar 3, 2001 at 12am to Mar 9, 2001 at 12am.")
          # Search with begin date/time and end date/time - should use and show given time
          perform_user_search("#commMessagesSearchForm", @student.id)
          set_value f('#commMessagesSearchForm .dateStartSearchField'), 'Mar 3, 2001 1:05p'
          set_value f('#commMessagesSearchForm .dateEndSearchField'), 'Mar 9, 2001 3p'
          f('#commMessagesSearchForm .userDateRangeSearchBtn').click
          wait_for_ajaximations
          f('#commMessagesSearchOverview').text.should contain("Notifications sent to #{@student.name} from Mar 3, 2001 at 1:05pm to Mar 9, 2001 at 3pm.")
        end

        it "should display search params used when given invalid input data" do
          load_admin_tools_page
          click_view_notifications_tab
          perform_user_search("#commMessagesSearchForm", @student.id)
          # Search with invalid dates
          set_value f('#commMessagesSearchForm .dateStartSearchField'), 'couch'
          set_value f('#commMessagesSearchForm .dateEndSearchField'), 'pillow'
          f('#commMessagesSearchForm .userDateRangeSearchBtn').click
          wait_for_ajaximations
          f('#commMessagesSearchOverview').text.should contain("Notifications sent to #{@student.name} from the beginning to now.")
        end

        it "should hide tab if account setting disabled" do
          @account.settings[:admins_can_view_notifications] = false
          @account.save!

          load_admin_tools_page
          wait_for_ajaximations
          tab = fj('#adminToolsTabs .notifications > a')
          tab.should be_nil
        end
      end

      context "without permissions" do
        it "should not see tab" do
          setup_account_admin({:view_notifications => false})
          load_admin_tools_page
          wait_for_ajaximations
          tab = fj('#adminToolsTabs .notifications > a')
          tab.should be_nil
        end
      end
    end
  end

  context "Logging" do
    it_should_behave_like "cassandra audit logs"

    it "should change log types with dropdown" do
      load_admin_tools_page
      click_view_tab "logging"

      select = fj('#loggingType')
      select.should_not be_nil
      select.should be_displayed

      change_log_type("Authentication")

      loggingTypeView = fj('#loggingAuthentication')
      loggingTypeView.should_not be_nil
      loggingTypeView.should be_displayed
    end

    context "permissions" do
      it "should not see tab" do
        setup_account_admin(
          view_statistics: false,
          manage_user_logins: false,
          view_grade_changes: false
        )
        load_admin_tools_page
        wait_for_ajaximations
        tab = fj('#adminToolsTabs .logging > a')
        tab.should be_nil
      end

      it "should see tab for view_statistics permission" do
        setup_account_admin(
          view_statistics: true,
          manage_user_logins: false,
          view_grade_changes: false
        )
        load_admin_tools_page
        wait_for_ajaximations
        tab = fj('#adminToolsTabs .logging > a')
        tab.text.should == "Logging"

        click_view_tab "logging"

        select = fj('#loggingType')
        select.should_not be_nil
        select.should be_displayed

        options = ffj("#loggingType > option")
        options.size.should eql(2)
        options[0].text.should == "Select a Log type"
        options[1].text.should == "Login / Logout Activity"
      end

      it "should see tab for manage_user_logins permission" do
        setup_account_admin(
          view_statistics: false,
          manage_user_logins: true,
          view_grade_changes: false
        )
        load_admin_tools_page
        wait_for_ajaximations
        tab = fj('#adminToolsTabs .logging > a')
        tab.text.should == "Logging"

        click_view_tab "logging"

        select = fj('#loggingType')
        select.should_not be_nil
        select.should be_displayed

        options = ffj("#loggingType > option")
        options.size.should eql(2)
        options[0].text.should == "Select a Log type"
        options[1].text.should == "Login / Logout Activity"
      end

      it "should see tab for view_grade_changes permission" do
        setup_account_admin(
          view_statistics: false,
          manage_user_logins: false,
          view_grade_changes: true
        )
        load_admin_tools_page
        wait_for_ajaximations
        tab = fj('#adminToolsTabs .logging > a')
        tab.text.should == "Logging"

        click_view_tab "logging"

        select = fj('#loggingType')
        select.should_not be_nil
        select.should be_displayed

        options = ffj("#loggingType > option")
        options.size.should eql(2)
        options[0].text.should == "Select a Log type"
        options[1].text.should == "Grade Change Activity"
      end
    end
  end

  context "Authentication Logging" do
    it_should_behave_like "cassandra audit logs"

    before do
      Auditors::Authentication.record(@student.pseudonyms.first, 'login')
      Auditors::Authentication.record(@student.pseudonyms.first, 'logout')
      load_admin_tools_page
      click_view_tab "logging"
      change_log_type("Authentication")
    end

    it "should show log history" do
      perform_user_search("#authLoggingSearchForm", @student.id)
      f('#authLoggingSearchForm .userDateRangeSearchBtn').click
      wait_for_ajaximations
      ff('#authLoggingSearchResults table tbody tr').length.should == 2
      cols = ffj('#authLoggingSearchResults table tbody tr:first td')
      cols.size.should == 3
      cols.last.text.should == "LOGOUT"
    end

    it "should search by user name" do
      perform_user_search("#authLoggingSearchForm", 'testuser')
      f('#authLoggingSearchForm .userDateRangeSearchBtn').click
      wait_for_ajaximations
      ff('#authLoggingSearchResults table tbody tr').length.should == 2
    end
  end

  context "Grade Change Logging" do
    it_should_behave_like "cassandra audit logs"

    before do
      course_with_teacher(course: @course, :user => user_with_pseudonym(:name => 'Teacher TestUser'))

      @assignment = @course.assignments.create!(:title => 'Assignment', :points_possible => 10)
      @submission = @assignment.grade_student(@student, grade: 7, grader: @teacher).first
      @submission = @assignment.grade_student(@student, grade: 8, grader: @teacher).first
      @submission = @assignment.grade_student(@student, grade: 9, grader: @teacher).first

      load_admin_tools_page
      click_view_tab "logging"
      change_log_type("GradeChange")
    end

    it "should search by grader name and show history" do
      perform_autocomplete_search("#grader_id-autocompleteField", @teacher.name)
      f('#loggingGradeChange button[name=gradeChange_submit]').click
      wait_for_ajaximations
      ff('#gradeChangeLoggingSearchResults table tbody tr').length.should == 3

      cols = ffj('#gradeChangeLoggingSearchResults table tbody tr:last td')
      cols.size.should == 8

      cols[2].text.should == "-"
      cols[3].text.should == "7"
      cols[4].text.should == @teacher.name
      cols[5].text.should == @student.name
      cols[6].text.should == @course.name
      cols[7].text.should == @assignment.title
    end

    it "should search by student name" do
      perform_autocomplete_search("#student_id-autocompleteField", @student.name)
      f('#loggingGradeChange button[name=gradeChange_submit]').click
      wait_for_ajaximations
      ff('#gradeChangeLoggingSearchResults table tbody tr').length.should == 3
    end

    it "should search by course id" do
      set_value f("#gradeChangeCourseSearch"), @course.id
      f('#loggingGradeChange button[name=gradeChange_submit]').click
      wait_for_ajaximations
      ff('#gradeChangeLoggingSearchResults table tbody tr').length.should == 3
    end

    it "should search by assignment id" do
      set_value f("#gradeChangeAssignmentSearch"), @assignment.id
      f('#loggingGradeChange button[name=gradeChange_submit]').click
      wait_for_ajaximations
      ff('#gradeChangeLoggingSearchResults table tbody tr').length.should == 3
    end
  end
end
