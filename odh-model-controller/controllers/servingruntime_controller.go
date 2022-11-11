package controllers

import (
	"context"
	"github.com/go-logr/logr"
	predictorv1 "github.com/kserve/modelmesh-serving/apis/serving/v1alpha1"
	routev1 "github.com/openshift/api/route/v1"
	corev1 "k8s.io/api/core/v1"
	authv1 "k8s.io/api/rbac/v1"
	apierrs "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

type OpenShiftServingRuntimeReconciler struct {
	client.Client
	Scheme       *runtime.Scheme
	Log          logr.Logger
	MeshDisabled bool
}

// Reconcile OpenShift objects for Serving Runtimes
func (r *OpenShiftServingRuntimeReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	// Initialize logger format
	log := r.Log.WithValues("Serving Runtime", req.Name, "namespace", req.Namespace)

	// Get the InferenceService object when a reconciliation event is triggered (create,
	// update, delete)
	servingRuntime := &predictorv1.ServingRuntime{}
	err := r.Get(ctx, req.NamespacedName, servingRuntime)
	if err != nil && apierrs.IsNotFound(err) {
		log.Info("Stop Serving Runtime reconciliation")
		return ctrl.Result{}, nil
	} else if err != nil {
		log.Error(err, "Unable to fetch the Serving Runtime")
		return ctrl.Result{}, err
	}

	err = r.ReconcileRoute(servingRuntime, ctx)
	if err != nil {
		return ctrl.Result{}, err
	}

	err = r.ReconcileSA(servingRuntime, ctx)
	if err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *OpenShiftServingRuntimeReconciler) SetupWithManager(mgr ctrl.Manager) error {
	builder := ctrl.NewControllerManagedBy(mgr).
		For(&predictorv1.ServingRuntime{}).
		Owns(&predictorv1.ServingRuntime{}).
		Owns(&corev1.Namespace{}).
		Owns(&routev1.Route{}).
		Owns(&corev1.ServiceAccount{}).
		Owns(&corev1.Service{}).
		Owns(&corev1.Secret{}).
		Owns(&authv1.ClusterRoleBinding{})

	err := builder.Complete(r)
	if err != nil {
		return err
	}

	return nil
}
