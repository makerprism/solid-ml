(** Full SSR App Example - Server
    
    This example demonstrates a complete SSR + hydration setup:
    1. Server renders HTML with reactive components (defined in Shared_components)
    2. Client hydrates the HTML to make it interactive
    3. Navigation works both server-side (full page) and client-side (SPA)
    
    Run with: make example-full-ssr
    Then visit: http://localhost:8080
*)

open Solid_ml_ssr

module Shared = Shared_components.Components.Make(Solid_ml_ssr.Env)
module Routes = Shared_components.Routes
module Filters = Shared_components.Filters.Make(Solid_ml_ssr.Env)
module Inline_edit = Shared_components.Inline_edit.Make(Solid_ml_ssr.Env)
module Async = Shared_components.Async.Make(Solid_ml_ssr.Env)

let sample_todos = Shared_components.Components.[
  { id = 1; text = "Learn solid-ml"; completed = true };
  { id = 2; text = "Build an SSR app"; completed = false };
  { id = 3; text = "Add hydration"; completed = false };
  { id = 4; text = "Deploy to production"; completed = false };
]

let sample_todos_filters : Shared_components.Filters.todo list = [
  { id = 1; text = "Learn solid-ml"; completed = true };
  { id = 2; text = "Build an SSR app"; completed = false };
  { id = 3; text = "Add hydration"; completed = false };
  { id = 4; text = "Deploy to production"; completed = false };
]

(** {1 Components} *)

(** Page layout with navigation - Updated to use Shared.app_layout structure *)
let layout ~title:page_title ~children () =
  (* We need to unwrap/cast the children because Server_Platform.Html.node = Solid_ml_ssr.Html.node *)
  let children_list = [children] in

  Html.(
    html ~lang:"en" ~children:[
      head ~children:[
        meta ~charset:"utf-8" ();
        meta ~name:"viewport" ~content:"width=device-width, initial-scale=1" ();
        title ~children:[text page_title] ();
        raw {|<style>
          * { box-sizing: border-box; }
          body { 
            font-family: system-ui, sans-serif; 
            max-width: 800px; 
            margin: 0 auto; 
            padding: 20px;
            background: #f5f5f5;
          }
          .app-container {
             background: white; 
             padding: 20px;
             border-radius: 8px;
             box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .nav {
             margin-bottom: 20px;
             padding: 15px;
             background: #f8f9fa;
             border-radius: 8px;
             border: 1px solid #e9ecef;
          }
          .nav-section {
             margin-bottom: 12px;
          }
          .nav-section:last-child {
             margin-bottom: 0;
          }
          .nav-section-title {
             font-size: 11px;
             text-transform: uppercase;
             letter-spacing: 0.5px;
             color: #6c757d;
             font-weight: 600;
             margin-right: 8px;
          }
          .nav-link {
            text-decoration: none;
            color: #4a90d9;
            font-weight: 500;
            font-size: 14px;
            margin-right: 4px;
          }
          .nav-link:hover {
            text-decoration: underline;
            color: #357abd;
          }
          .nav-link.active {
            color: #1f5c9c;
            text-decoration: underline;
            font-weight: 600;
          }
          .counter-display { 
            font-size: 48px; 
            font-weight: bold; 
            text-align: center;
            padding: 20px;
            background: #f0f0f0;
            border-radius: 8px;
            margin: 20px 0;
          }
          .buttons { display: flex; gap: 10px; justify-content: center; }
          .btn {
            padding: 10px 24px;
            font-size: 18px;
            border: none;
            border-radius: 4px;
            background: #4a90d9;
            color: white;
            cursor: pointer;
          }
          .btn:hover { background: #357abd; }
          .btn-secondary { background: #888; }
          .btn-secondary:hover { background: #666; }
          .todo-list { list-style: none; padding: 0; }
          .todo {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px;
            border-bottom: 1px solid #eee;
            cursor: pointer;
            user-select: none;
          }
          .todo:hover {
            background-color: #f9f9f9;
          }
          .todo .checkbox {
            display: inline-block;
            width: 32px;
            text-align: center;
            font-family: monospace;
            font-size: 16px;
            font-weight: bold;
            color: #4a90d9;
            flex-shrink: 0;
          }
          .todo.completed {
            text-decoration: line-through;
            color: #999;
          }
          .hydration-status {
            padding: 8px 16px;
            background: #e8f5e9;
            border-radius: 4px;
            color: #2e7d32;
            margin-top: 20px;
            display: none;
          }
          .hydration-status.active { display: block; }
          .filters-container h1 {
            font-size: 28px;
            margin-bottom: 20px;
            color: #333;
          }
          .filter-bar {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
          }
          .filter-btn {
            padding: 8px 16px;
            border: 2px solid #4a90d9;
            border-radius: 4px;
            background: white;
            color: #4a90d9;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.2s;
          }
          .filter-btn:hover {
            background: #f0f8ff;
          }
          .filter-btn.active {
            background: #4a90d9;
            color: white;
          }
          .search-bar {
            margin-bottom: 20px;
          }
          .search-input {
            width: 100%;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 4px;
            font-size: 16px;
            box-sizing: border-box;
          }
          .search-input:focus {
            outline: none;
            border-color: #4a90d9;
          }
          .stats-bar {
            display: flex;
            gap: 20px;
            padding: 12px;
            background: #f8f9fa;
            border-radius: 4px;
            margin-bottom: 20px;
          }
          .stat {
            font-weight: bold;
            color: #555;
          }
          .status-bar {
            margin-top: 20px;
            padding: 12px;
            background: #fff3cd;
            border-radius: 4px;
            color: #856404;
            font-weight: bold;
          }
          .inline-edit-container h1 {
            font-size: 28px;
            margin-bottom: 20px;
            color: #333;
          }
          .instructions {
            font-style: italic;
            color: #666;
            margin-bottom: 20px;
          }
          .editable-list {
            list-style: none;
            padding: 0;
          }
          .editable-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px;
            border-bottom: 1px solid #eee;
          }
          .editable-item.editing {
            background: #f0f8ff;
            border-left: 4px solid #4a90d9;
          }
          .item-text {
            flex: 1;
            padding: 8px;
            border-radius: 4px;
          }
          .btn-edit {
            margin-left: auto;
            padding: 6px 12px;
            border: 1px solid #4a90d9;
            border-radius: 4px;
            background: white;
            color: #4a90d9;
            cursor: pointer;
            font-size: 14px;
          }
          .btn-edit:hover {
            background: #f0f8ff;
          }
          .edit-input {
            flex: 1;
            padding: 8px;
            border: 2px solid #4a90d9;
            border-radius: 4px;
            font-size: 16px;
          }
          .edit-input:focus {
            outline: none;
            border-color: #357abd;
            box-shadow: 0 0 0 3px rgba(74, 144, 217, 0.1);
          }
          .btn-save {
            padding: 8px 16px;
            border: none;
            border-radius: 4px;
            background: #28a745;
            color: white;
            cursor: pointer;
            font-weight: bold;
          }
          .btn-save:hover {
            background: #218838;
          }
          .btn-cancel {
            padding: 8px 16px;
            border: none;
            border-radius: 4px;
            background: #dc3545;
            color: white;
            cursor: pointer;
            font-weight: bold;
          }
          .btn-cancel:hover {
            background: #c82333;
          }
          .todo-text.saving {
            color: #999;
            font-style: italic;
          }
          .async-container {
            margin: 20px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
          }
          .async-container h1 {
            font-size: 28px;
            margin-bottom: 10px;
            color: #333;
          }
          .async-container h2 {
            font-size: 24px;
            margin-bottom: 15px;
            color: #444;
          }
          .async-container h3 {
            font-size: 18px;
            margin-bottom: 10px;
            color: #555;
          }
          .async-container .intro {
            color: #666;
            margin-bottom: 20px;
            line-height: 1.6;
          }
          .async-container .instructions {
            font-style: italic;
            color: #666;
            margin-bottom: 20px;
            padding: 12px;
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            border-radius: 4px;
          }
          .section-divider {
            border: none;
            border-top: 1px solid #ddd;
            margin: 30px 0;
          }
          .resource-demo {
            background: white;
            padding: 20px;
            border-radius: 8px;
          }
          .status-bar {
            padding: 12px 16px;
            border-radius: 4px;
            margin-bottom: 20px;
            font-weight: 500;
          }
          .status-bar.idle {
            background: #e3f2fd;
            color: #1976d2;
          }
          .status-bar.loading {
            background: #fff3e0;
            color: #f57c00;
          }
          .status-bar.success {
            background: #e8f5e9;
            color: #2e7d32;
          }
          .status-bar.error {
            background: #ffebee;
            color: #c62828;
          }
          .spinner {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid #f57c00;
            border-top-color: transparent;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin-right: 8px;
            vertical-align: middle;
          }
          @keyframes spin {
            to { transform: rotate(360deg); }
          }
          .user-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #e0e0e0;
          }
          .user-header {
            display: flex;
            align-items: center;
            gap: 16px;
            margin-bottom: 16px;
          }
          .user-avatar {
            width: 64px;
            height: 64px;
            border-radius: 50%;
            background: #4a90d9;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 28px;
            font-weight: bold;
          }
          .user-name {
            margin: 0 0 4px 0;
            font-size: 22px;
            color: #333;
          }
          .user-email {
            margin: 0;
            color: #666;
          }
          .user-bio {
            margin-top: 16px;
            padding: 12px;
            background: #f5f5f5;
            border-radius: 4px;
          }
          .user-bio h3 {
            margin: 0 0 8px 0;
            font-size: 16px;
            color: #555;
          }
          .user-bio p {
            margin: 0;
            color: #666;
          }
          .user-meta {
            margin-top: 16px;
            display: flex;
            align-items: center;
            gap: 12px;
            flex-wrap: wrap;
          }
          .user-id {
            padding: 4px 12px;
            background: #e3f2fd;
            color: #1976d2;
            border-radius: 12px;
            font-size: 14px;
            font-weight: 500;
          }
          .fetch-time {
            padding: 4px 12px;
            background: #e8f5e9;
            color: #2e7d32;
            border-radius: 12px;
            font-size: 14px;
            font-weight: 500;
          }
          .error-card {
            background: #ffebee;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #ef9a9a;
          }
          .error-card h3 {
            margin: 0 0 12px 0;
            color: #c62828;
          }
          .error-message {
            margin: 0 0 16px 0;
            color: #555;
          }
          .error-actions {
            display: flex;
            gap: 8px;
          }
          .sequential-demo {
            background: white;
            padding: 20px;
            border-radius: 8px;
          }
          .steps-container {
            margin: 20px 0;
          }
          .step-item {
            display: flex;
            align-items: flex-start;
            gap: 16px;
            padding: 16px;
            background: #f5f5f5;
            border-radius: 8px;
            margin-bottom: 12px;
            transition: all 0.3s;
          }
          .step-item.active {
            background: #e3f2fd;
            border-left: 4px solid #2196f3;
          }
          .step-item.complete {
            background: #e8f5e9;
            border-left: 4px solid #4caf50;
          }
          .step-indicator {
            flex-shrink: 0;
          }
          .step-number {
            display: inline-block;
            width: 32px;
            height: 32px;
            border-radius: 50%;
            background: #9e9e9e;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
          }
          .step-item.active .step-number {
            background: #2196f3;
          }
          .step-item.complete .step-number {
            background: #4caf50;
          }
          .step-item.complete .check {
            display: inline-block;
            width: 32px;
            height: 32px;
            border-radius: 50%;
            background: #4caf50;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
          }
          .step-content {
            flex: 1;
          }
          .step-content h3 {
            margin: 0 0 8px 0;
            font-size: 18px;
          }
          .step-status {
            margin: 0;
            font-size: 14px;
            font-weight: 500;
          }
          .step-status.pending {
            color: #9e9e9e;
          }
          .step-status.loading {
            color: #ff9800;
          }
          .step-status.success {
            color: #4caf50;
          }
          .demo-controls {
            display: flex;
            gap: 12px;
            margin-top: 20px;
          }
          .button-group {
            display: flex;
            gap: 8px;
          }
          /* Undo-Redo CSS */
          .undo-redo-container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
          }
          .undo-redo-container h1 {
            color: #2c3e50;
            margin-bottom: 10px;
          }
          .undo-redo-container .intro {
            color: #666;
            margin-bottom: 30px;
          }
          .text-list-container {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
          }
          .text-list-container h3 {
            margin: 0 0 15px 0;
            color: #2c3e50;
          }
          .text-list {
            list-style: none;
            padding: 0;
            margin: 0 0 15px 0;
            min-height: 50px;
          }
          .text-item {
            display: flex;
            align-items: center;
            padding: 10px;
            background: white;
            border-radius: 4px;
            margin-bottom: 8px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
          }
          .text-index {
            font-weight: bold;
            color: #495057;
            margin-right: 10px;
            min-width: 30px;
          }
          .text-content {
            flex: 1;
            color: #212529;
          }
          .text-list .empty {
            color: #adb5bd;
            font-style: italic;
            padding: 10px;
            text-align: center;
          }
          .list-info {
            display: flex;
            justify-content: flex-end;
          }
          .list-info .count {
            font-size: 14px;
            color: #6c757d;
          }
          .history-indicator {
            display: flex;
            justify-content: space-between;
            padding: 15px;
            background: #e7f3ff;
            border-radius: 6px;
            margin-bottom: 20px;
            font-size: 14px;
          }
          .history-indicator span {
            padding: 5px 10px;
            border-radius: 4px;
            font-weight: 500;
          }
          .history-past {
            background: #fff3cd;
            color: #856404;
          }
          .history-present {
            background: #d4edda;
            color: #155724;
          }
          .history-future {
            background: #cce5ff;
            color: #004085;
          }
          .action-buttons {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
          }
          .action-buttons .button-group {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            display: flex;
            flex-direction: column;
          }
          .action-buttons .button-group h3 {
            margin: 0 0 15px 0;
            font-size: 16px;
            color: #495057;
          }
          .action-buttons .button-group button {
            margin-bottom: 8px;
          }
          .action-buttons .button-group button:last-child {
            margin-bottom: 0;
          }
          .history-controls {
            grid-column: 1 / -1;
            flex-direction: row;
            align-items: center;
            background: #fff3cd;
          }
          .history-controls h3 {
            margin-right: 20px;
            margin-bottom: 0;
          }
          .btn-undo {
            background: #ffc107;
            color: #212529;
          }
          .btn-undo:hover:not(:disabled) {
            background: #e0a800;
          }
          .btn-redo {
            background: #17a2b8;
            color: white;
          }
          .btn-redo:hover:not(:disabled) {
            background: #138496;
          }
          .btn-danger {
            background: #dc3545;
            color: white;
          }
          .btn-danger:hover:not(:disabled) {
            background: #c82333;
          }
          .undo-redo-container .instructions {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #007bff;
          }
          .undo-redo-container .instructions h3 {
            margin: 0 0 15px 0;
            color: #2c3e50;
          }
          .undo-redo-container .instructions ul {
            margin: 0;
            padding-left: 20px;
          }
          .undo-redo-container .instructions li {
            margin-bottom: 8px;
            color: #495057;
          }
          /* Theme CSS */
          .theme-container {
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
          }
          .theme-container h1 {
            color: #2c3e50;
            margin-bottom: 10px;
          }
          .theme-container .intro {
            color: #666;
            margin-bottom: 30px;
          }
          .current-theme-display {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
            margin-bottom: 30px;
            font-size: 18px;
          }
          .theme-label-text {
            font-weight: 500;
            color: #495057;
          }
          .theme-icon {
            width: 24px;
            height: 24px;
          }
          .theme-name {
            font-weight: 600;
            color: #212529;
            text-transform: capitalize;
          }
          .theme-selector h2 {
            margin: 0 0 20px 0;
            color: #2c3e50;
          }
          .theme-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
          }
          .theme-card {
            background: white;
            border: 3px solid #dee2e6;
            border-radius: 12px;
            padding: 24px;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
          }
          .theme-card:hover {
            border-color: #007bff;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
          }
          .theme-card.selected {
            border-color: #28a745;
            background: #f0fff4;
          }
          .theme-preview {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 12px;
          }
          .theme-card .theme-icon {
            width: 48px;
            height: 48px;
            padding: 8px;
            border-radius: 50%;
            background: #f8f9fa;
          }
          .theme-card-Light .theme-icon {
            background: #fff3cd;
          }
          .theme-card-Dark .theme-icon {
            background: #343a40;
            color: white;
          }
          .theme-card-Auto .theme-icon {
            background: #e7f3ff;
          }
          .theme-label {
            font-weight: 500;
            color: #495057;
            text-transform: capitalize;
          }
          .theme-check {
            position: absolute;
            top: 8px;
            right: 8px;
            background: #28a745;
            color: white;
            width: 24px;
            height: 24px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
          }
          .section-divider {
            height: 1px;
            background: #dee2e6;
            margin: 40px 0;
          }
          .theme-details {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
            margin: 30px 0;
          }
          @media (max-width: 768px) {
            .theme-details {
              grid-template-columns: 1fr;
            }
          }
          .theme-info {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
          }
          .theme-info h3 {
            margin: 0 0 12px 0;
            color: #2c3e50;
          }
          .theme-description {
            color: #6c757d;
            margin: 0 0 16px 0;
            line-height: 1.6;
          }
          .theme-features h4 {
            margin: 0 0 10px 0;
            color: #495057;
            font-size: 16px;
          }
          .theme-features ul {
            margin: 0;
            padding-left: 20px;
          }
          .theme-features li {
            margin-bottom: 6px;
            color: #495057;
          }
          .color-palette {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
          }
          .color-palette h3 {
            margin: 0 0 16px 0;
            color: #2c3e50;
          }
          .palette-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(80px, 1fr));
            gap: 12px;
          }
          .color-item {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 8px;
          }
          .color-swatch {
            width: 60px;
            height: 60px;
            border-radius: 8px;
            border: 2px solid #dee2e6;
          }
          .color-item span {
            font-size: 12px;
            color: #6c757d;
          }
          .bg-primary { background: #007bff; }
          .bg-secondary { background: #6c757d; }
          .bg-success { background: #28a745; }
          .bg-danger { background: #dc3545; }
          .bg-warning { background: #ffc107; }
          .bg-info { background: #17a2b8; }
          .storage-info {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #ffc107;
          }
          .storage-info h3 {
            margin: 0 0 12px 0;
            color: #2c3e50;
          }
          .storage-info p {
            margin: 0 0 16px 0;
            color: #6c757d;
          }
          .storage-details {
            display: flex;
            flex-direction: column;
            gap: 8px;
            margin-bottom: 16px;
          }
          .storage-key, .storage-value {
            font-family: monospace;
            padding: 8px 12px;
            background: white;
            border-radius: 4px;
            border: 1px solid #dee2e6;
            font-size: 14px;
          }
          .storage-key {
            color: #495057;
          }
          .storage-value {
            color: #28a745;
          }
          .theme-container .instructions {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #007bff;
            margin-top: 30px;
          }
          .theme-container .instructions h3 {
            margin: 0 0 12px 0;
            color: #2c3e50;
          }
          .theme-container .instructions ul {
            margin: 0;
            padding-left: 20px;
          }
          .theme-container .instructions li {
            margin-bottom: 8px;
            color: #495057;
          }
          /* Wizard CSS */
          .wizard-container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
          }
          .wizard-container h1 {
            color: #2c3e50;
            margin-bottom: 10px;
          }
          .wizard-container .intro {
            color: #666;
            margin-bottom: 30px;
          }
          .progress-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            position: relative;
            padding: 20px 0;
            margin-bottom: 30px;
          }
          .progress-line {
            position: absolute;
            top: 50%;
            left: 0;
            right: 0;
            height: 4px;
            background: #e9ecef;
            transform: translateY(-50%);
            z-index: 0;
          }
          .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #007bff, #28a745);
            transition: width 0.3s ease;
          }
          .progress-step {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 8px;
            z-index: 1;
            position: relative;
          }
          .progress-circle {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: white;
            border: 3px solid #dee2e6;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 600;
            color: #6c757d;
            transition: all 0.3s ease;
          }
          .progress-circle.current {
            border-color: #007bff;
            background: #e7f3ff;
            color: #007bff;
            transform: scale(1.1);
          }
          .progress-circle.completed {
            background: #28a745;
            border-color: #28a745;
            color: white;
          }
          .progress-label {
            font-size: 12px;
            color: #6c757d;
            font-weight: 500;
          }
          .wizard-content {
            min-height: 400px;
            padding: 30px;
            background: #f8f9fa;
            border-radius: 8px;
            margin-bottom: 30px;
          }
          .wizard-step h2 {
            margin: 0 0 12px 0;
            color: #2c3e50;
          }
          .step-intro {
            color: #6c757d;
            margin-bottom: 24px;
          }
          .step-content {
            margin-top: 24px;
          }
          .info-card {
            background: white;
            padding: 24px;
            border-radius: 8px;
            border-left: 4px solid #007bff;
          }
          .info-card h3 {
            margin: 0 0 16px 0;
            color: #2c3e50;
          }
          .info-card ul {
            margin: 0;
            padding-left: 20px;
          }
          .info-card li {
            margin-bottom: 8px;
            color: #495057;
          }
          .validation-errors {
            background: #ffebee;
            border-left: 4px solid #dc3545;
            padding: 16px;
            margin-top: 20px;
            border-radius: 4px;
          }
          .validation-errors h3 {
            margin: 0 0 12px 0;
            color: #c62828;
            font-size: 16px;
          }
          .validation-errors ul {
            margin: 0;
            padding-left: 20px;
          }
          .validation-errors li {
            margin-bottom: 8px;
            color: #c62828;
          }
          .form-group {
            margin-bottom: 20px;
          }
          .form-group label {
            display: block;
            margin-bottom: 6px;
            font-weight: 500;
            color: #495057;
          }
          .form-control {
            width: 100%;
            padding: 10px 12px;
            border: 1px solid #ced4da;
            border-radius: 4px;
            font-size: 14px;
            transition: border-color 0.15s ease;
          }
          .form-control:focus {
            outline: none;
            border-color: #007bff;
            box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
          }
          .error-text {
            display: block;
            color: #dc3545;
            font-size: 12px;
            margin-top: 4px;
          }
          .form-hint {
            font-size: 12px;
            color: #6c757d;
            margin-top: 8px;
          }
          .checkbox-group {
            display: flex;
            flex-direction: column;
            gap: 8px;
          }
          .checkbox-label {
            display: flex;
            align-items: center;
            gap: 8px;
            cursor: pointer;
            margin: 0;
          }
          .checkbox-label input {
            margin: 0;
            cursor: pointer;
          }
          .confirm-section {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
          }
          .confirm-section h3 {
            margin: 0 0 16px 0;
            color: #2c3e50;
            border-bottom: 2px solid #e9ecef;
            padding-bottom: 8px;
          }
          .confirm-item {
            display: flex;
            padding: 12px 0;
            border-bottom: 1px solid #f1f3f4;
          }
          .confirm-item:last-child {
            border-bottom: none;
          }
          .confirm-item .label {
            font-weight: 500;
            color: #6c757d;
            width: 120px;
          }
          .confirm-item .value {
            color: #212529;
            font-weight: 500;
          }
          .success-message {
            text-align: center;
            padding: 40px 20px;
          }
          .success-icon {
            width: 80px;
            height: 80px;
            margin: 0 auto 20px;
            background: #28a745;
            color: white;
            font-size: 40px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .success-message h2 {
            margin: 0 0 16px 0;
            color: #28a745;
          }
          .wizard-nav {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 20px 0;
          }
          .nav-spacer {
            width: 100px;
          }
          .wizard-container .instructions {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #007bff;
            margin-top: 30px;
          }
          .wizard-container .instructions h3 {
            margin: 0 0 12px 0;
            color: #2c3e50;
          }
          .wizard-container .instructions ul {
            margin: 0;
            padding-left: 20px;
          }
          .wizard-container .instructions li {
            margin-bottom: 8px;
            color: #495057;
          }
        </style>|};
      ] ();
      body ~children:[
        (* Import map for Melange runtime and local modules - must come before module scripts *)
        raw {|<script type="importmap">
{
  "imports": {
    "melange.js/": "/static/melange.js/",
    "melange/": "/static/node_modules/melange/",
    "melange.__private__/": "/static/node_modules/melange.__private__/",
    "full_ssr_app/": "/static/examples/full_ssr_app/",
    "full_ssr_app.__private__/": "/static/node_modules/full_ssr_app.__private__/",
    "full_ssr_app.__private__.shared_components/": "/static/node_modules/full_ssr_app.__private__.shared_components/",
    "solid-ml-browser/": "/static/node_modules/solid-ml-browser/",
    "solid-ml/": "/static/node_modules/solid-ml/",
    "solid-ml-internal/": "/static/node_modules/solid-ml-internal/",
    "solid-ml-template-runtime/": "/static/node_modules/solid-ml-template-runtime/"
  }
}
</script>|};
        (* App root for true hydration *)
        Html.div ~id:"app" ~children:children_list ();

        (* Initial state for hydration *)
        raw (Render.get_hydration_script ());

        (* Hydration script *)
        script ~src:"/static/client.js" ~type_:"module" ~children:[] ();
      ] ()
    ] ()
  )

(** Home page *)
let home_page ~current_path () =
  layout ~title:"Home - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Shared.home_page ()
    ) ()
  ) ()

(** Counter page - uses Shared.counter *)
let counter_page ~current_path ~initial () =
  layout ~title:"Counter - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Shared.counter_content ~initial ()
    ) ()
  ) ()

(** Todos page - uses Shared.todo_list *)
let todos_page ~current_path ~todos () =
  layout ~title:"Todos - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Shared.todos_content ~initial_todos:todos ()
    ) ()
  ) ()

(** Filters page - uses Filters.view *)
let filters_page ~current_path ~todos () =
  layout ~title:"Filters - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Filters.view ~initial_todos:todos ()
    ) ()
  ) ()

(** 404 page *)
let not_found_page ~current_path ~request_path () =
  layout ~title:"Not Found - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Html.div ~children:[
        Html.h2 ~children:[Html.text "404 - Page Not Found"] ();
        Html.p ~children:[
          Html.text ("The page " ^ request_path ^ " was not found.");
        ] ();
      ] ()
    ) ()
  ) ()

(** {1 Request Handlers} *)

let handle_home req =
  let html = Render.to_document (fun () ->
    home_page ~current_path:(Dream.target req) ())
  in
  Dream.html html

let handle_keyed _req =
  let html =
    Render.to_document (fun () ->
      layout ~title:"Keyed - solid-ml SSR" ~children:(
        Shared.app_layout ~current_path:(Routes.path Routes.Keyed) ~children:(
          Shared.keyed_demo ()
        ) ()
      ) ())
  in
  Dream.html html

let handle_template_keyed _req =
  let module T = Shared_components.Template_keyed.Make (Solid_ml_ssr.Env) in
  let html =
    Render.to_document (fun () ->
      layout ~title:"Template-Keyed - solid-ml SSR" ~children:(
        Shared.app_layout ~current_path:(Routes.path Routes.Template_keyed) ~children:(
          T.view ()
        ) ()
      ) ())
  in
  Dream.html html

let handle_counter req =
  let initial = 
    Dream.query req "count"
    |> Option.map int_of_string_opt
    |> Option.join
    |> Option.value ~default:0
  in
  let counter_key = State.key ~namespace:"full_ssr" "counter" in
  let html = Render.to_document (fun () ->
    State.set_encoded ~key:counter_key ~encode:State.encode_int initial;
    counter_page ~current_path:(Routes.path Routes.Counter) ~initial ())
  in
  Dream.html html

let handle_todos _req =
  let todos_key = State.key ~namespace:"full_ssr" "todos" in
  let html = Render.to_document (fun () ->
    let encode_todo (todo : Shared_components.Components.todo) =
      State.encode_object [
        ("id", State.encode_int todo.id);
        ("text", State.encode_string todo.text);
        ("completed", State.encode_bool todo.completed);
      ]
    in
    State.set_encoded
      ~key:todos_key
      ~encode:State.encode_list
      (List.map encode_todo sample_todos);
    todos_page ~current_path:(Routes.path Routes.Todos) ~todos:sample_todos ())
  in
  Dream.html html

let handle_filters _req =
  let html = Render.to_document (fun () ->
    filters_page ~current_path:(Routes.path Routes.Filters) ~todos:sample_todos_filters ())
  in
  Dream.html html

(** Inline-edit page - uses Inline_edit.view *)
let inline_edit_page ~current_path () =
  layout ~title:"Inline Edit - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Inline_edit.view ()
    ) ()
  ) ()

let handle_inline_edit _req =
  let html = Render.to_document (fun () ->
    inline_edit_page ~current_path:(Routes.path Routes.Inline_edit) ())
  in
  Dream.html html

(** Async page - uses Async.view *)
let handle_async _req =
  let module Async = Shared_components.Async.Make(Solid_ml_ssr.Env) in
  let html =
    Render.to_document (fun () ->
      layout ~title:"Async - solid-ml SSR" ~children:(
        Shared.app_layout ~current_path:(Routes.path Routes.Async) ~children:(
          Async.view ()
        ) ()
      ) ())
  in
  Dream.html html

(** Undo-Redo page - uses Undo_redo.view *)
let handle_undo_redo _req =
  let module Undo_redo = Shared_components.Undo_redo.Make(Solid_ml_ssr.Env) in
  let html =
    Render.to_document (fun () ->
      layout ~title:"Undo-Redo - solid-ml SSR" ~children:(
        Shared.app_layout ~current_path:(Routes.path Routes.Undo_redo) ~children:(
          Undo_redo.view ()
        ) ()
      ) ())
  in
  Dream.html html

(** Theme page - uses Theme.view *)
let handle_theme _req =
  let module Theme = Shared_components.Theme.Make(Solid_ml_ssr.Env) in
  let html =
    Render.to_document (fun () ->
      layout ~title:"Theme - solid-ml SSR" ~children:(
        Shared.app_layout ~current_path:(Routes.path Routes.Theme) ~children:(
          Theme.view ()
        ) ()
      ) ())
  in
  Dream.html html

(** Wizard page - uses Wizard.view *)
let handle_wizard _req =
  let module Wizard = Shared_components.Wizard.Make(Solid_ml_ssr.Env) in
  let html =
    Render.to_document (fun () ->
      layout ~title:"Wizard - solid-ml SSR" ~children:(
        Shared.app_layout ~current_path:(Routes.path Routes.Wizard) ~children:(
          Wizard.view ()
        ) ()
      ) ())
  in
  Dream.html html

let handle_not_found req =
  let path = Dream.target req in
  let html = Render.to_document (fun () ->
    not_found_page ~current_path:path ~request_path:path ())
  in
  Dream.html ~status:`Not_Found html

(** {1 Main Server} *)

let () =
  let port =
    match Sys.getenv_opt "PORT" with
    | Some p -> (try int_of_string p with _ -> 8080)
    | None -> 8080
  in

  Printf.printf "=== solid-ml Full SSR Demo ===\n";
  Printf.printf "Server running at http://localhost:%d\n" port;
  Printf.printf "\n";
  Printf.printf "Pages:\n";
  Printf.printf "  http://localhost:%d/             - Home\n" port;
  Printf.printf "  http://localhost:%d/counter      - Counter\n" port;
  Printf.printf "  http://localhost:%d/todos        - Todos\n" port;
  Printf.printf "  http://localhost:%d/filters      - Filters\n" port;
  Printf.printf "  http://localhost:%d/inline-edit  - Inline-Edit\n" port;
  Printf.printf "  http://localhost:%d/async        - Async\n" port;
  Printf.printf "  http://localhost:%d/undo-redo    - Undo-Redo\n" port;
  Printf.printf "  http://localhost:%d/theme        - Theme\n" port;
  Printf.printf "  http://localhost:%d/wizard       - Wizard\n" port;
  Printf.printf "\n";
  Printf.printf "Build client with: make example-full-ssr-client\n";
  Printf.printf "Press Ctrl+C to stop\n";
  flush stdout;

  Dream.run ~port ~interface:"0.0.0.0"
  @@ Dream.logger
  @@ Dream.router [
    Dream.get "/" handle_home;
    Dream.get "/counter" handle_counter;
    Dream.get "/todos" handle_todos;
    Dream.get "/filters" handle_filters;
    Dream.get "/inline-edit" handle_inline_edit;
    Dream.get "/async" handle_async;
    Dream.get "/undo-redo" handle_undo_redo;
    Dream.get "/theme" handle_theme;
    Dream.get "/wizard" handle_wizard;
    Dream.get "/keyed" handle_keyed;
    Dream.get "/template-keyed" handle_template_keyed;
    Dream.get "/static/**" (Dream.static "examples/full_ssr_app/static");
    Dream.any "/**" handle_not_found;
  ]
