module AccessibleRecord
  def self.included(base)
    base.extend(MacroMethods)              
  end
  
  module MacroMethods          
    def has_accessible(*args)
      write_inheritable_attribute(:accessible_associations, args)

      unless self.is_a? AccessibleRecord::ClassMethods
        extend AccessibleRecord::ClassMethods
        class_eval do
          include AccessibleRecord::InstanceMethods
        end
      end
    end
  end
  
  module ClassMethods
    def accessible_associations
      read_inheritable_attribute(:accessible_associations)
    end
  end

  module InstanceMethods
    def attributes=(attributes)
      self.class.read_inheritable_attribute(:accessible_associations).each do |attribute|
        if association = self.class.reflect_on_association(attribute)
          case association.macro
          when :has_one, :belongs_to
            if attr_params = attributes.delete(attribute)
              if (attr_object = self.send(attribute)).nil?
                attr_object = association.klass.new(attr_params)
                self.send("#{attribute}=".to_sym, attr_object)
              else
                attr_object.attributes=(attr_params)
              end
            end
          when :has_many
            attr_params = attributes.delete(attribute) || []
            if attr_params.is_a?(Array)
              destroyed = []
              self.send(attribute).each do |attr_object|
                if (attr_sub_params = attr_params.shift).nil?
                  destroyed << attr_object
                else
                  attr_object.attributes=(attr_sub_params)
                end
              end
              destroyed.each do |attr_object|
                self.send(attribute).delete(attr_object)
              end
              attr_params.each do |attr_sub_params|
                attr_object = association.klass.new(attr_sub_params)
                self.send(attribute).push(attr_object)
              end
            end
          end
        end
      end
      super(attributes)
    end
  end
end

ActiveRecord::Base.send(:include, AccessibleRecord)