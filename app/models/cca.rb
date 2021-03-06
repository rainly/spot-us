class Cca < ActiveRecord::Base
	validates_presence_of   :sponsor_id, :title
	validate :check_credit_settings, :on => [:update, :new]
	belongs_to :user, :foreign_key => :sponsor_id
	has_many :cca_questions, :order => "position"
	has_many :cca_answers
  has_many :credits, :foreign_key=>'cca_id'
  
	named_scope :cca_home, :conditions=>'status=1', :order => 'RAND()'
	
	def self.STATUS_VALUES
		["Pending","Live","Finished"]
	end
	
	
	def has_begun?(user)
		CcaAnswer.find_by_user_id_and_cca_id(user.id, self.id)
	end

	def number_of_answers
		cca_answers.any? ? cca_answers.count(:select=>"distinct user_id") : 0
	end

	def sections
		cca_questions.all(:select=>"distinct section", :conditions=>'section is not null and section!=""').map(&:section).compact
	end

	def check_credit_settings
		if self.award_amount > self.max_credits_amount
			errors.add_to_base("Award amount cannot be greater than maximum credit amount")
		end
	end

	def survey_completed?(user)
		# checks if user has completed this survey
		completed_answer = self.cca_answers.find(:first, :conditions => "user_id = #{user.id} and status = 1")
		return false if completed_answer.blank?
		return true
	end

	def award_credit(user)
		Credit.create(:user_id => user.id, :amount => self.award_amount, 
		                      :description => "Awarded for #{self.title} | #{self.id}", :cca_id=>self.id)
		self.process_credits_awarded(self.award_amount)
		self.set_completed_status(user)
	end 

	def process_credits_awarded(amount)
		self.credits_awarded = self.credits_awarded + amount
		self.status = 2 if self.credits_awarded > self.max_credits_amount
		self.save!
	end
  
	def set_completed_status(user)
		# cca_answers status is completed when user has answered all required questions
		self.cca_answers.update_all("status = 1", "user_id = #{user.id}" )
	end

	def is_pending?
		self.status == 0 ? true : false
	end
  
	def is_live?
		self.status == 1 ? true : false
	end

	def is_maxed_out?
		self.status == 2 ? true : false
	end
  
	def status?
		return "Pending" if is_pending?
		return "Live" if is_live?
		return "Finished" if is_maxed_out?
		return "Unknown"
	end
  
	def to_s
		title
	end
  
	def to_param
		begin 
			"#{id}-#{to_s.parameterize}"
		rescue
			"#{id}"
		end
	end
  
	def generate_csv
		FasterCSV.generate do |csv|
			csv << ['Question', 'User', 'Answers']
			cca_questions.each do |question|
				csv << [question.question, '', '']
				question.cca_answers.each do |answer|
					csv << ['',(answer.user ? answer.user.full_name : "deleted user"), answer.answer]
				end
			end
		end
	end

	def process_answers(answers, user)
		form_incomplete = false
		self.cca_questions.each do |question|
			answer_incomplete = false
			answer = eval("answers[:question_#{question.id}]") || nil
			if question.question_type == "checkbox"
				answer_incomplete = true if !answer || answer.size == 0
			else
				answer_incomplete = true if !answer || answer.strip == ""
			end
			form_incomplete = true if answer_incomplete and question.required == true 
			# insert/update db for items that are completed
			if answer_incomplete == false
				answer = answer.join("\n") if question.question_type == "checkbox"
				existing_answer = CcaAnswer.find_by_cca_question_id_and_user_id(question.id,user.id)
				if existing_answer
					CcaAnswer.update(existing_answer.id, :answer => answer)
				else
					CcaAnswer.create(:cca_id => self.id, :user_id => user.id, :cca_question_id => question.id, :answer => answer)
				end
			end
		end
		# return whether form is finished or user needs to still fill out elements
		!form_incomplete
	end
	
	def already_submitted?(user)
		answer = CcaAnswer.find_by_user_id_and_cca_id_and_status(user,self.id,1)
		answer ? true : false
	end
    
end
