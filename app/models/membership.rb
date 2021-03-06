class Membership < ActiveRecord::Base
  belongs_to :business
  belongs_to :contact
  belongs_to :payment_type
  has_many :installments
  has_one :enrollment

  validates :value, :numericality =>  {:greater_than_or_equal => 0}
  validates :business, :presence => true
  validates :contact, :presence => true
  validates :begins_on, :presence => true
  validates :ends_on, :presence => true
  validates_datetime :ends_on, :after => :begins_on
  validates :monthly_due_day, :numericality =>  {:greater_than => 0, :less_than => 29}

  # Setup accessible (or protected) attributes for your model
  attr_accessible :contact_id, :business_id, :payment_type_id, :begins_on, :ends_on, :value, :closed_on, :vip, :external_id, :monthly_due_day, :name

  after_save :update_contacts_current_membership

  after_initialize :init
 
  include BelongsToPadmaContact

  def closed?
    closed_on.present?
  end

  def overdue?
    ends_on < Date.today
  end

  def due?
    (Date.today..Date.today.end_of_month).include? ends_on
  end

  def as_json_for_messaging
    json = as_json
    json["ends_on"] = ends_on
    json["contact_id"] = contact.padma_id
    json["recipient_email"] = contact.email
    json["username"] = contact.padma_teacher
    json["account_name"] = business.padma_id
    json
  end

  def self.build_from_csv(business, row)
    membership = Membership.new

    padma_contact = PadmaContact.find_by_kshema_id(row[4])

    return unless padma_contact

    fnz_contact = Contact.find_or_create_by_padma_id(:padma_id => padma_contact.id,
                                                 :business_id => business.id,
                                                 :name => "#{padma_contact.first_name} #{padma_contact.last_name}".strip,
                                                 :padma_status => padma_contact.status,
                                                 :padma_teacher => padma_contact.global_teacher_username)

    membership.attributes = {
        :business_id => business.id,
        :begins_on => Date.parse(row[2]),
        :ends_on => Date.parse(row[3]),
        :vip => row[5] == 'true',
        :contact_id => fnz_contact.id,
        :external_id => row[0].to_i,
        :monthly_due_day => 10,
        :value => 0 # Kshêma doesnt store plan value
    }

    unless row[8].blank? # if cancelled
      membership.closed_on = Date.parse(row[8]) # Kshêma doesnt store cancellation date
    end

    return membership
  end

  def self.csv_header
    "id,nombre,ini,fin,alumno_id,vip,obs,forma_id,canceled,school_id,person_name,created_at,updated_at".split(',')
  end

  def update_contacts_current_membership
  	if closed?
  		contact.update_attribute(:current_membership_id, nil)
  	else
  		contact.update_attribute(:current_membership_id, self.id)
  	end
  end

  private
  
  def init
    if self.new_record? && self.monthly_due_day.nil?
      self.monthly_due_day = 10
    end
  end

end
