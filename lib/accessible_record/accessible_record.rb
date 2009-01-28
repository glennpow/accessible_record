module AccessibleRecord
  def self.included(base)
    base.extend(MacroMethods)
  end
  
  module MacroMethods
    def has_accessible(*args)
      unless self.is_a? AccessibleRecord::ClassMethods
        extend AccessibleRecord::ClassMethods
        class_eval do
          include AccessibleRecord::InstanceMethods
        end
      end

      self.accessible_associations.concat(args.map(&:to_sym))
    end
  end
  
  module ClassMethods
    def accessible_associations
      associations = read_inheritable_attribute(:accessible_associations)
      write_inheritable_attribute(:accessible_associations, associations = []) if associations.nil?
      associations
    end
  end

  module InstanceMethods
    def attributes=(attributes)
      attributes = attributes.deep_symbolize_keys
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
            attr_params = attributes.delete(attribute)
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
    
    def valid?
      super
      
      self.class.read_inheritable_attribute(:accessible_associations).each do |attribute|
        if association = self.class.reflect_on_association(attribute)
          case association.macro
          when :has_one, :belongs_to
            if attr_object = self.send(attribute)
              unless attr_object.valid?
                attr_object.errors.each_full do |message|
                  self.errors.add(attribute, message)
                end
              end
            end
          when :has_many
            self.send(attribute).each do |attr_object|
              unless attr_object.valid?
                attr_object.errors.each_full do |message|
                  self.errors.add(attribute, message)
                end
              end
            end
          end
        end
      end
        
      errors.empty?
    end
  end
end

ActiveRecord::Base.send(:include, AccessibleRecord) if defined?(ActiveRecord::Base)