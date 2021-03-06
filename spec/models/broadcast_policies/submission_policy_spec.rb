require File.expand_path('../../spec_helper', File.dirname(__FILE__))

module BroadcastPolicies
  describe SubmissionPolicy do

    let(:course) do
      stub("Course").tap do |c|
        c.stubs(:available?).returns(true)
        c.stubs(:id).returns(1)
      end
    end
    let(:assignment) do
      stub("Assignment").tap do |a|
        a.stubs(:context).returns(course)
        a.stubs(:muted?).returns(false)
        a.stubs(:published?).returns(true)
        a.stubs(:context_id).returns(course.id)
      end
    end
    let(:enrollment) do
      stub("Enrollment").tap do |e|
        e.stubs(:course_id).returns(course.id)
      end
    end
    let(:user) do
      stub("User").tap do |u|
        u.stubs(:student_enrollments).returns([enrollment])
      end
    end
    let(:submission_time) do
      Time.now
    end
    let(:prior_version) do
      stub("PriorVersion").tap do |v|
        v.stubs(:submitted_at).returns(submission_time)
      end
    end
    let(:submission) do
      stub("Submission").tap do |s|
        s.stubs(:group_broadcast_submission).returns(false)
        s.stubs(:assignment).returns(assignment)
        s.stubs(:just_created).returns(true)
        s.stubs(:submitted?).returns(true)
        s.stubs(:changed_state_to).returns(false)
        s.stubs(:prior_version).returns(prior_version)
        s.stubs(:submitted_at).returns(submission_time)
        s.stubs(:has_submission?).returns(true)
        s.stubs(:late?).returns(false)
        s.stubs(:quiz_submission).returns(nil)
        s.stubs(:user).returns(user)
      end
    end

    let(:policy) { SubmissionPolicy.new(submission) }

    describe '#should_dispatch_assignment_submitted_late?' do
      before { submission.stubs(:late?).returns true }
      def wont_send_when
        yield
        policy.should_dispatch_assignment_submitted_late?.should be_false
      end

      it 'is true with the inputs are true' do
        policy.should_dispatch_assignment_submitted_late?.should be_true
      end
      specify { wont_send_when {
        submission.stubs(:group_broadcast_submission).returns true
      } }
      specify { wont_send_when {
        course.stubs(:available?).returns false
      } }
      specify { wont_send_when { submission.stubs(:submitted?).returns false} }
      specify { wont_send_when { submission.stubs(:has_submission?).returns false } }
      specify { wont_send_when { submission.stubs(:late?).returns false } }

      it "still sends when the state was just changed even when it wasn't just created" do
        submission.stubs(:just_created).returns false
        submission.stubs(:changed_state_to).with(:submitted).returns true
        policy.should_dispatch_assignment_submitted_late?.should be_true
      end
    end

    describe '#should_dispatch_assignment_submitted?' do
      def wont_send_when
        yield
        policy.should_dispatch_assignment_submitted?.should be_false
      end

      it 'is true when the relevant inputs are true' do
        policy.should_dispatch_assignment_submitted?.should be_true
      end
      specify { wont_send_when { course.stubs(:available?).returns false}}
      specify { wont_send_when { submission.stubs(:submitted?).returns false }}
      specify { wont_send_when { submission.stubs(:late?).returns true }}
    end

    describe '#should_dispatch_assignment_resubmitted' do
      before do
        prior_version.stubs(:submitted_at).returns (Time.now - 100)
      end

      def wont_send_when
        yield
        policy.should_dispatch_assignment_resubmitted?.should be_false
      end

      it 'is true when the relevant inputs are true' do
        policy.should_dispatch_assignment_resubmitted?.should be_true
      end
      specify { wont_send_when { course.stubs(:available?).returns false}}
      specify { wont_send_when { submission.stubs(:submitted?).returns false }}
      specify { wont_send_when { prior_version.stubs(:submitted_at).returns nil }}
      specify { wont_send_when { submission.stubs(:has_submission?).returns false }}
      specify { wont_send_when { submission.stubs(:late?).returns true }}
    end

    describe '#should_dispatch_group_assignment_submitted_late?' do
      before do
        submission.stubs(:group_broadcast_submission).returns true
        submission.stubs(:late?).returns true
      end

      def wont_send_when
        yield
        policy.should_dispatch_group_assignment_submitted_late?.should be_false
      end

      it 'returns true when the inputs are all true' do
        policy.should_dispatch_group_assignment_submitted_late?.should be_true
      end
      specify { wont_send_when { submission.stubs(:group_broadcast_submission).returns false }}
      specify { wont_send_when { course.stubs(:available?).returns false}}
      specify { wont_send_when { submission.stubs(:submitted?).returns false}}
      specify { wont_send_when { submission.stubs(:late?).returns false }}
    end

    describe '#should_dispatch_submission_graded?' do
      before do
        submission.stubs(:changed_state_to).with(:graded).returns true
      end

      def wont_send_when
        yield
        policy.should_dispatch_submission_graded?.should be_false
      end

      it 'returns true when all inputs are true' do
        policy.should_dispatch_submission_graded?.should be_true
      end

      specify { wont_send_when{ assignment.stubs(:muted?).returns true }}
      specify { wont_send_when{ course.stubs(:available?).returns false}}
      specify { wont_send_when{ submission.stubs(:quiz_submission).returns stub }}
      specify { wont_send_when{ assignment.stubs(:published?).returns false}}
    end


    describe '#should_dispatch_submission_grade_changed?' do
      before do
        submission.stubs(:graded_at).returns Time.now
        submission.stubs(:assignment_graded_in_the_last_hour?).returns false
        submission.stubs(:assignment_just_published).returns true
      end

      def wont_send_when
        yield
        policy.should_dispatch_submission_grade_changed?.should be_false
      end

      it 'returns true when all inputs are true' do
        policy.should_dispatch_submission_grade_changed?.should be_true
      end

      specify { wont_send_when{ assignment.stubs(:muted?).returns true }}
      specify { wont_send_when{ submission.stubs(:graded_at).returns nil }}
      specify { wont_send_when{ submission.stubs(:quiz_submission).returns stub }}
      specify { wont_send_when{ course.stubs(:available?).returns false }}
      specify { wont_send_when{ assignment.stubs(:published?).returns false }}
    end

  end
end
