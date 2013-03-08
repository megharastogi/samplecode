if (typeof(ideeli) === 'undefined') {
  ideeli = {};
}

var splashwindow = '';

ideeli.SplashModal = Class.create({
  initialize: function(options) {  
    this.options = options;
    this.my_modal = '';   
    splashwindow = this; 
    this.addSplashModal();
  },
    addSplashModal: function(){
       var splash_modal = document.createElement('div');
       splash_modal.setAttribute('id',"splash_modal");
       splash_modal.setAttribute('style',"display:none;position:absolute;");
       if (this.options.click_url == undefined || this.options.click_url.blank())
         {           
           var image = document.createElement('img');  
           image.setAttribute('src', (this.options.image_url));
           if(this.options.close_on_click == 1) {
             image.observe('click', function(){ splashwindow.splashModalClose();});
           }
           splash_modal.appendChild(image);
         }
       else 
        {  
          var image_anchor = document.createElement('a');
          image_anchor.setAttribute('href', this.options.click_url);
          if (this.options.target == undefined || this.options.target == "blank")
            {image_anchor.setAttribute('target', "_blank");}
          var image = document.createElement('img');  
          image.setAttribute('src', (this.options.image_url));
          image.setAttribute('width',this.options.width);
          image.setAttribute('height',this.options.height);
          image_anchor.appendChild(image);
          splash_modal.appendChild(image_anchor);
        }
  
       if (this.options.close_link == undefined || this.options.close_link == true)
        {
          close_anchor = document.createElement('a');
          close_anchor.setAttribute('id','splash_modal_close')
          close_anchor.setAttribute('href','javascript:splashwindow.splashModalClose();');
          text = document.createElement('textNode');
          close_anchor.appendChild(text);
          splash_modal.appendChild(close_anchor);
        }
       document.getElementsByTagName('body')[0].appendChild(splash_modal);
    },
    splashModalOpen: function() {
     this.my_modal = new Control.Modal($('splash_modal'), {
           className: 'modal',  
           closeOnClick: 'overlay',
           constrainToViewport: true,
           isOpen: false,
           overlayOpacity: 0.5,
           width:parseInt(this.options.width),
           height:parseInt(this.options.height),
           afterClose :function(){
             $('splash_modal').remove(); 
           }
         });
       this.my_modal.open();
    },
    splashModalClose: function() {
      this.my_modal.close();
    } 
});
