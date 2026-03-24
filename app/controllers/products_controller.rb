class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy delete_image ]
  before_action :authenticate_user!, except: %i[ index show ]

  # GET /products or /products.json
  def index
    @products = Product.all
  end

  # GET /products/1 or /products/1.json
  def show
  end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit
  end

  # POST /products or /products.json
  def create
    # Extract images before params.expect
    new_images = params.dig(:product, :images)

    @product = Product.new(product_params)

    respond_to do |format|
      if @product.save
        # Attach images after successful save
        @product.images.attach(new_images) if new_images.present? && new_images.any?(&:present?)

        format.html { redirect_to @product, notice: "Product was successfully created." }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1 or /products/1.json
  def update
    # Extract images before params.expect
    new_images = params.dig(:product, :images)

    respond_to do |format|
      if @product.update(product_params)
        # Attach new images after successful update (appends instead of replacing)
        @product.images.attach(new_images) if new_images.present? && new_images.any?(&:present?)

        format.html { redirect_to @product, notice: "Product was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1/delete_image
  def delete_image
    image = @product.images.find(params[:image_id])
    image.purge
    redirect_to edit_product_path(@product), notice: "Image was successfully removed."
  end

  # DELETE /products/1 or /products/1.json
  def destroy
    @product.destroy!

    respond_to do |format|
      format.html { redirect_to products_path, notice: "Product was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def product_params
      params.expect(product: [ :name, :description, :price ])
    end
end
