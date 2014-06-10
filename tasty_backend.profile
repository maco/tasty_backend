<?php
/**
 * @file
 * Enables modules and site configuration for a Tasty Backend site installation.
 */

/**
 * Implements hook_install_tasks().
 */
function tasty_backend_install_tasks(&$install_state) {
  
  $tasks = array(
    'tasty_backend_settings_form' => array(
      'display_name' => st('Additional options'),
      'type' => 'form',
    ),
  );
  
  return $tasks;
}

/**
 * Create a settings form to choose the Standard or Minimal Tasty Backend.
 */
function tasty_backend_settings_form() {
  $form = array();
  
  $form['intro'] = array(
    '#markup' => '<h1>' . st('Tasty Backend Options') . '</h1>',
  );
  
  $form['standard_profile'] = array(
    '#type' => 'radios',
    '#title' => st('Choose Standard or Minimal Tasty Backend'),
    '#options' => array(
      'standard' => st('Standard'),
      'minimal' => st('Minimal'),
    ),
    '#default_value' => 'standard',
    '#description' => st('The Standard option will create content types, roles, and other options included in Drupal\'s Standard install. The minimal option will only add in minimal configuration.'),
    '#required' => TRUE,
  );
  
  $form['submit'] = array(
    '#type' => 'submit',
    '#value' => st('Continue'),
  );
  
  return $form;
}

/**
 * Submit handler for settings form.
 */
function tasty_backend_settings_form_submit($form, &$form_state) {
  $values = $form_state['values'];
  
  if ($values['standard_profile'] == 'standard') {
    $module_list = array(
      'tasty_backend_standard',
    );
    module_enable($module_list);
    drupal_set_message('The Tasty Backend Standard module has been installed.');
  }
  else {
    drupal_set_message('The minimal option was selected.');
  }
}

/**
 * Implements hook_field_group_info().
 */
function tasty_backend_field_group_info() {
  $export = array();
  
  // Create a "Main Content" field group for all content types except article.
  $types = node_type_get_names();
  foreach ($types as $type => $name) {
    if ($type != 'article') {
      tasty_backend_main_content_field_group($export, $type);
    }
  }
  
  return $export;
}

/**
 * Create a "Main Content" field group that can be reused.
 */
function tasty_backend_main_content_field_group(&$export, $type) {
  
  $field_group = new stdClass();
  $field_group->disabled = FALSE;
  $field_group->api_version = 1;
  $field_group->identifier = 'group_main_content|node|' . $type . '|form';
  $field_group->group_name = 'group_main_content';
  $field_group->entity_type = 'node';
  $field_group->bundle = $type;
  $field_group->mode = 'form';
  $field_group->parent_name = '';
  $field_group->data = array(
    'label' => 'Main Content',
    'weight' => '0',
    'children' => array(
      0 => 'title',
      1 => 'body',
    ),
    'format_type' => 'tab',
    'format_settings' => array(
      'formatter' => 'closed',
      'instance_settings' => array(
        'description' => '',
        'classes' => 'group-main-content field-group-tab',
        'required_fields' => 1,
      ),
    ),
  );
  $export['group_main_content|node|' . $type . '|form'] = $field_group;
  
  return $export;
}

/**
* Implements hook_ctools_plugin_api().
*/
function tasty_backend_ctools_plugin_api($owner, $api) {
  if ($owner == 'field_group' && $api == 'field_group') {
    return array('version' => 1);
  }
  if ($owner == "page_manager" && $api == "pages_default") {
    return array("version" => "1");
  }
}

/**
 * Implements hook_views_api().
 */
function tasty_backend_views_api() {
  return array("version" => "3.0");
}

/**
 * Implements hook_action_info().
 * 
 * Add missing action to bulk activate users.
 */
function tasty_backend_action_info() {
  return array(
    'tasty_backend_activate_user_action' => array(
      'type' => 'user',
      'label' => t('Activate user'),
      'configurable' => FALSE,
      'triggers' => array('any'),
    ),
  );
}

/**
 * Action to activate a user.
 */
function tasty_backend_activate_user_action($user) {
  user_save($user, array('status' => '1'));
}

/**
 * Implements hook_form_FORM_ID_alter().
 * Alter the path of the 'Add term' link to point to our custom 'Add tags' context admin page.
 */
function tasty_backend_form_taxonomy_overview_terms_alter(&$form, &$form_state, $form_id) {
  // Make sure we only alter the link on our custom pages.
  $vocabularies = taxonomy_vocabulary_get_names();
  foreach ($vocabularies as $vocabulary => $vocabulary_info) {
    $page = page_manager_get_current_page();
    if ($page && $page['subtask'] == 'manage_' . $vocabulary ) {
      $form['#empty_text'] = t('No terms available. <a href="@link">Add term</a>.', array('@link' => url('admin/manage/categories/' . drupal_html_class($vocabulary) . '/add')));
    }
  }
}

/**
 * Implements hook_menu_link_alter().
 */
function tasty_backend_menu_link_alter(&$item) {
  // Add a description for this menu link, can't seem to set it in the page manager code.
  // Checking if it's empty first so if a user overrides this in the UI it won't revert back to this.
  $vocabularies = taxonomy_vocabulary_get_names();
  foreach ($vocabularies as $vocabulary => $vocabulary_info) {
    if ($item['link_path'] == 'admin/manage/categories/' . drupal_html_class($vocabulary) && empty($item['options']['attributes']['title'])) {
      $item['options']['attributes']['title'] = t('Manage all terms in the "' . $vocabulary_info->name . '" vocabulary.');
    }
  }
}

/**
 * Implements hook_form_FORM_ID_alter() for install_configure_form().
 *
 * Allows the profile to alter the site configuration form.
 */
function tasty_backend_form_install_configure_form_alter(&$form, $form_state) {
  // Pre-populate the site name with the server name.
  $form['site_information']['site_name']['#default_value'] = $_SERVER['SERVER_NAME'];
}

/**
 * Set a new submit handler on permissions form.
 *
 * See tasty_backend_nav_menu_items().
 */
function tasty_backend_form_user_admin_permissions_alter(&$form, $form_state) {
  $form['#submit'][] = 'tasty_backend_nav_menu_items';
}

/**
 * Custom submit handler for permissions form.
 * 
 * Create a menu item for each menu the 'content admin' user role has permissions to administer.
 */
function tasty_backend_nav_menu_items(&$form, $form_state) {
  $content_role = user_role_load_by_name('content admin');
  $menus = menu_get_menus();
  $permissions = user_role_permissions(array($content_role->rid => $content_role->name));

  foreach($menus as $menu => $name) {
    if ($menu != 'main-menu' && isset($permissions[$content_role->rid]['administer ' . $menu . ' menu items'])) {
      $item = array(
        'link_title' => t($name),
        'link_path' => 'admin/structure/menu/manage/' . $menu,
        'menu_name' => 'navigation',
        'plid' => variable_get('tasty_backend_menus_mlid'),
      );
      menu_link_save($item);
  
      // Update the menu router information.
      menu_rebuild();
    }
  }
}